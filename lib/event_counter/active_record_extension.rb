class EventCounter < ActiveRecord::Base
  # This module adds functionality to ActiveRecord
  module ActiveRecordExtension
    extend ActiveSupport::Concern

    included do
      class_attribute :event_counters
      self.event_counters = {}
    end

    # :nodoc:
    module ClassMethods
      def event_counter_for(name, interval)
        event_counters[name] = interval

        clause = { name: name.to_s }

        if ActiveRecord::VERSION::MAJOR > 3
          has_many name,
            -> { where(clause) }, as: :countable, class_name: 'EventCounter'
        else
          has_many name,
            conditions: clause, as: :countable, class_name: 'EventCounter'
        end
        include CountableInstanceMethods
        extend  CountableClassMethods
      end
    end

    # This module defines instance methods for a countable model
    module CountableInstanceMethods

      def up!(*args)
        opts = args.extract_options!
        opts.merge!(vector: :up)
        rotate_counter(*args, opts)
      end

      def down!(*args)
        opts = args.extract_options!
        opts.merge!(vector: :down)
        rotate_counter(*args, opts)
      end

      def data_for(name, opts = {})
        self.class.data_for(name, id, opts)
      end

      private

      def rotate_counter(*args)
        opts = args.extract_options!
        name, val = args
        unless respond_to?(name)
          self.class.counter_error!(:not_found, name: name)
        end
        send(name).change(val, opts)
      end
    end

    # This module defines class methods for a countable model
    module CountableClassMethods

      INTERVALS = {
        year: 1.year,
        month: 1.month,
        week: 1.week,
        day: 1.day
      }.freeze

      def data_for(name, id = nil, interval: nil, range: nil, raw: nil, tz: nil)
        interval = normalize_interval!(name, interval)

        range = normalize_range!(range, interval) if range

        tz ||= (Time.zone || 'UTC')
        tz_abbr = tz.now.zone

        subq = EventCounter
          .select(subq_select(interval, tz_abbr))
          .where(name: name, countable_type: self)
          .where(id && { countable_id: id })
          .within(range)
          .group("1")
          .order("1")
          .to_sql

        sql = <<-SQL.squish!
          SELECT created_at, value
          FROM (#{series(interval, range, tz_abbr)}) intervals
          LEFT OUTER JOIN (#{subq}) counters USING (created_at)
          ORDER BY 1
        SQL

        result = connection.execute(sql).to_a

        raw ? result : normalize_counters_data(result, tz)
      end

      def subq_select(interval, tz)
        "#{subq_extract(interval, tz)} as created_at, sum(value) AS value"
      end

      def subq_extract(interval, tz)
        case interval
        when Symbol
          "date_trunc(#{sanitize(interval)}, #{tstamp_tz('created_at', tz)})"
        else
          time = <<-SQL
            floor(EXTRACT(EPOCH FROM created_at) /
            #{sanitize(interval)})::int * #{sanitize(interval)}
          SQL
          tstamp_tz("to_timestamp(#{time})", tz)
        end
      end

      def series(interval, range, tz)
        a =
          case interval
          when Symbol
            series_for_symbol(interval, range, tz)
          else
            series_for_integer(interval, range, tz)
          end
        EventCounter.within(range).select(<<-SQL).to_sql
          count(*), generate_series(#{a[0]}, #{a[1] }, #{a[2]}) AS created_at
        SQL
      end

      def series_for_symbol(interval, range, tz)
        interval_sql = "interval '1 #{interval}'"
        if range
          a = [
            dtrunc(interval, sanitize(range.min).to_s, tz),
            dtrunc(interval, sanitize(range.max).to_s, tz),
            interval_sql
          ]
        else
          a = [
            dtrunc(interval, 'min(created_at)', tz),
            dtrunc(interval, 'max(created_at)', tz),
            interval_sql
          ]
        end
      end

      def series_for_integer(interval, range, tz)
        interval_sql = %Q(#{sanitize(interval)} * interval '1 seconds')
        if range
          a = [
            tstamp_tz("to_timestamp(#{sanitize(range.min.to_i)})", tz),
            tstamp_tz("to_timestamp(#{sanitize(range.max.to_i)})", tz),
            interval_sql
          ]
        else
          a = [
            tstamp_tz('min(created_at)', tz),
            tstamp_tz('max(created_at)', tz),
            interval_sql
          ]
        end
      end

      def dtrunc(interval, value, tz)
        "date_trunc(#{sanitize(interval)}, #{tstamp_tz(value, tz)})"
      end

      def tstamp_tz(str, tz)
        "#{str}::timestamptz AT TIME ZONE #{sanitize(tz)}"
      end

      def counter_error!(*args)
        fail EventCounter::CounterError, args
      end

      def normalize_interval!(name, interval)
        default_interval = default_interval_for(name)

        h = {
          default_interval: default_interval,
          interval: interval,
          model: self.class.name
        }

        return default_interval.to_i unless interval

        counter_error!(:not_found, name: name) unless default_interval
        counter_error!(:less, h) if less_then_default?(default_interval, interval)
        unless multiple_of_default?(default_interval, interval)
          counter_error!(:multiple, h)
        end

        interval.respond_to?(:to_i) ? interval.to_i : interval
      end

      def less_then_default?(*args)
        default, provided = args.map do |arg|
          interval_as_integer(arg)
        end
        provided < default
      end

      def multiple_of_default?(default_interval, provided)
        return true if provided.is_a?(Symbol)
        provided.modulo(default_interval).zero?
      end

      def interval_as_integer(interval)
        interval.is_a?(Symbol) ? INTERVALS[interval] : interval
      end

      def normalize_counters_data(data, tz)
        Time.use_zone(tz) do
          data.map { |i| [ Time.zone.parse(i['created_at']), i['value'].to_i ] }
        end
      end

      def default_interval_for(name)
        event_counters[name.to_sym]
      end

      def normalize_range!(range, interval)
        range_min, range_max =
          case interval
          when Symbol
            [
              range.min.send(:"beginning_of_#{interval}"),
              range.max.send(:"end_of_#{interval}")
            ]
          else
            [ range.min.floor(interval), range.max.floor(interval) ]
          end

        # TODO: ensure that range in time zone
        range_min..range_max
      end
    end
  end

end
