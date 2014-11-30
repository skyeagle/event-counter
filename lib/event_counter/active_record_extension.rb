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
      def has_counter(name, interval: :day)
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

      def data_for(name, id = nil, interval: nil, range: nil, raw: nil)
        interval = normalize_interval!(name, interval)

        range = normalize_range!(range, interval) if range

        tz = Time.zone.tzinfo.identifier
        tz_storage = (default_timezone == :utc ? 'UTC' : Time.now.zone)

        subq = EventCounter
          .select(subq_select(interval, tz))
          .where(name: name, countable_type: self)
          .where(id && { countable_id: id })
          .within(range)
          .group("1")
          .order("1")
          .to_sql

        q = <<-SQL.squish!
          SELECT created_at, value
          FROM (#{series(interval, tz, range)}) intervals
          LEFT OUTER JOIN (#{subq}) counters USING (created_at)
          ORDER BY 1
        SQL

        result = connection.execute(q).to_a

        raw ? result : normalize_counters_data!(result)
      end

      def subq_select(interval, tz)
        "#{subq_extract(interval, tz)} as created_at, sum(value) AS value"
      end

      def subq_extract(interval, tz)
        case interval
        when Symbol
          dtrunc(interval, 'created_at', tz)
        else
          time = floor_tstamp('created_at', interval)
          if default_timezone == :utc
            "to_timestamp(#{time})"
          else
            at_tz("to_timestamp(#{time})::timestamp", Time.new.zone)
          end
        end
      end

      def floor_tstamp(tstamp, interval)
        <<-SQL
          floor(EXTRACT(EPOCH FROM #{tstamp}) /
          #{sanitize(interval)})::int * #{sanitize(interval)}
        SQL
      end

      def series(*args)
        args.first.is_a?(Symbol) ? series_symbol(*args) : series_integer(*args)
      end

      def series_symbol(interval, tz, range = nil)
        if range
          series_symbol_with_range(interval, tz, range)
        else
          series_symbol_without_range(interval, tz)
        end
      end

      def series_symbol_with_range(interval, tz, range)
        range_min, range_max = range.min, range.max
        a = [
          dtrunc(interval, sanitize(range_min.to_s(:db)), tz),
          dtrunc(interval, sanitize(range_max.to_s(:db)), tz),
          interval_symbol(interval)
        ]

        "SELECT generate_series(#{a[0]}, #{a[1]}, #{a[2]}) AS created_at"
      end

      def series_symbol_without_range(interval, tz)
        a = [
          dtrunc(interval, 'min(created_at)', tz),
          dtrunc(interval, 'max(created_at)', tz),
          interval_symbol(interval)
        ]
        EventCounter.select(<<-SQL).to_sql
          generate_series(#{a[0]}, #{a[1]}, #{a[2]}) AS created_at
        SQL
      end

      def series_integer(interval, tz, range = nil)
        if range
          series_integer_with_range(interval, tz, range)
        else
          series_integer_without_range(interval, tz)
        end
      end

      def series_integer_with_range(interval, tz, range = nil)
        interval_sql = %Q(#{sanitize(interval)} * interval '1 seconds')
        range_min, range_max = range.min.to_s(:db), range.max.to_s(:db)

        a = [ sanitize(range_min), sanitize(range_max), interval_sql ]
        <<-SQL
          SELECT generate_series(#{a[0]}, #{a[1]}, #{a[2]}) AS created_at
        SQL
      end

      def series_integer_without_range(interval, tz)
        interval_sql = sanitize(interval)
        if default_timezone == :utc
          a = [
            floor_tstamp('min(created_at)', interval),
            floor_tstamp('max(created_at)', interval),
            interval_sql
          ]
        else
          z = Time.new.zone
          a = [
            floor_tstamp(at_tz('min(created_at)', z), interval),
            floor_tstamp(at_tz('max(created_at)', z), interval),
            interval_sql
          ]
        end
        EventCounter.select(<<-SQL).to_sql
          to_timestamp(generate_series(#{a[0]}, #{a[1]}, #{a[2]})) AS created_at
        SQL
      end

      def interval_symbol(interval)
        "interval #{sanitize(interval).insert(1, '1 ')}"
      end

      def dtrunc(interval, str, tz)
        "date_trunc(#{sanitize(interval)}, #{at_tz("#{str}::timestamptz", tz)})"
      end

      def at_tz(str, tz)
        "#{str} AT TIME ZONE #{sanitize(tz)}"
      end

      def counter_error!(*args)
        fail EventCounter::CounterError, args
      end

      def normalize_interval!(name, interval)
        default_interval = interval_as_integer(default_interval_for(name))

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

      def normalize_counters_data!(data)
        data.map do |i|
          [ Time.zone.parse(i['created_at']), i['value'].to_i ]
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
