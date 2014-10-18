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

      def data_for(name, interval: nil, range: nil, raw: false)
        self.class.data_for(name, id, interval: interval, range: range, raw: raw)
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

      def data_for(counter_name, id = nil, interval: nil, range: nil, raw: false)
        interval = normalize_interval!(counter_name, interval)

        sql = <<SQL.squish!
#{cte_definition(counter_name, interval, id)}
SELECT
  created_at,
  COALESCE(sum(value) OVER (PARTITION BY counters.created_at) , 0) AS value
FROM (#{series_definition(interval, range)}) intervals
LEFT JOIN CTE counters USING (created_at)
ORDER BY 1
SQL

        result = connection.execute(sql).to_a

        raw ? result : normalize_counters_data(result)
      end

      def cte_definition(counter_name, interval, id = nil)
<<SQL
WITH CTE AS (
  SELECT #{cte_extract(interval)} as created_at, sum(value) AS value
  FROM event_counters
  WHERE
    countable_type = #{sanitize(name)} AND
    #{ "countable_id = #{sanitize(id)} AND" if id.present? }
    name = #{sanitize(counter_name)}
  GROUP BY 1
)
SQL
      end

      def cte_extract(interval)
        case interval
        when Symbol
          "date_trunc(#{sanitize(interval)}, created_at)"
        else
          tstamp(<<SQL)
floor(EXTRACT(EPOCH FROM created_at::timestamp with time zone) /
#{sanitize(interval)})::int * #{sanitize(interval)}
SQL
        end
      end

      def series_definition(interval, range)
        range_min, range_max = min_and_max_of_range(interval, range)

        args =
          case interval
          when Symbol
            interval_sql = "interval '1 #{interval}'"
            if range
              [
                "date_trunc(#{sanitize(interval)}, #{tstamp(range.min.to_i)} )",
                "date_trunc(#{sanitize(interval)}, #{tstamp(range.max.to_i)} )",
                interval_sql
              ]
            else
              [
                "date_trunc(#{sanitize(interval)}, min(created_at))",
                "date_trunc(#{sanitize(interval)}, max(created_at))",
                interval_sql
              ]
            end
          else
            interval_sql = %Q(#{sanitize(interval)} * interval '1 seconds')
            if range
              [
                tstamp(sanitize(range_min)),
                tstamp(sanitize(range_max)),
                interval_sql
              ]
            else
              [ 'min(created_at)', 'max(created_at)', interval_sql ]
            end
          end
        <<SQL
SELECT
  count(*), generate_series(#{args[0]}, #{args[1] }, #{args[2]}) AS created_at
FROM CTE
SQL
      end

      def tstamp(val)
        "to_timestamp(#{val})"
      end

      def counter_error!(*args)
        fail EventCounter::CounterError, args
      end

      def normalize_interval!(counter_name, interval)
        default_interval = default_interval_for(counter_name)

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

      def normalize_counters_data(raw_data)
        raw_data.map  do |i|
          [ Time.parse(i['created_at']), i['value'].to_i ]
        end
      end

      def default_interval_for(counter_name)
        event_counters[counter_name.to_sym]
      end

      def min_and_max_of_range(interval, range)
        return unless range

        case interval
        when Symbol
          [
            range.min.send(:"beginning_of_#{interval}").to_i,
            range.max.send(:"end_of_#{interval}").to_i
          ]
        else
          [ range.min.floor(interval).to_i, range.max.floor(interval).to_i ]
        end
      end
    end
  end

end
