require 'event_counter/version'

# This class defines model that stores all counters.
class EventCounter < ActiveRecord::Base
  include EventCounterVersion

  belongs_to :countable, polymorphic: true

  scope :within, ->(range) { range && where(created_at: range) }

  def increase_by(val)
    self.class.where(id: id).update_all(['value = value + ?', val])
    increment(:value, val)
    self
  end

  def decrease_by(decrement)
    self.class.where(id: id).update_all(['value = value - ?', decrement])
    decrement(:value, decrement)
    self
  end

  def reset_value(val = 0)
    self.class.where(id: id).update_all(['value = ?', val])
    self.value = val
    self
  end

  def self.make(val = 1, on_time: nil, force: false)
    on_time = normalize_on_time!(on_time)

    attrs = { created_at: on_time }

    if force && (found = scoped_relation.where(attrs).first)
      found.reset_value(val)
    else
      attrs.merge!(value: val)
      scoped_relation.create!(attrs)
    end
  end

  def self.current_interval
    scoped_relation.proxy_association.owner.event_counters[counter_name]
  end

  def self.counter_name
    scoped_relation.proxy_association.reflection.name
  end

  def self.change(val = 1, vector: :up, on_time: nil, force: nil)
    counter_error!(:direction) unless [:up, :down].include?(vector)

    val ||= 1

    on_time = normalize_on_time!(on_time)

    counter = where(created_at: on_time).first

    return counter.update!(vector, val, force) if counter

    val = -val if vector == :down
    make(val, on_time: on_time, force: force)
  end

  def update!(vector, val = 1, force = false)
    if force
      val = -val if vector == :down
      reset_value(val)
    else
      vector == :up ? increase_by(val) : decrease_by(val)
    end
  end

  def self.scoped_relation
    ActiveRecord::VERSION::MAJOR > 3 ? where(nil) : scoped
  end

  def self.up!(*args)
    change(:up, *args)
  end

  def self.down!(*args)
    change(:down, *args)
  end

  def self.counter_error!(*args)
    fail CounterError, args
  end

  def self.normalize_on_time!(on_time)
    on_time ||= Time.zone.now

    counter_error!(:time_zone) unless on_time.is_a?(ActiveSupport::TimeWithZone)

    on_time =
      case current_interval
      when Symbol
        on_time.in_time_zone.send(:"beginning_of_#{current_interval}")
      else
        on_time.in_time_zone.floor(current_interval)
      end
    on_time
  end

  # Default error class
  class CounterError < StandardError
    MESSAGES = {
      not_found: 'Unable to find counter (%{name}).',
      direction: 'Wrong direction for counter.' \
                 'Possible values are :up and :down as symbols.',
      less: 'Specified interval (%{interval}) could not be less then ' \
            'a defined (%{default_interval}) in a countable model (%{model}).',
      multiple: 'Specified interval (%{interval}) should be a multiple of ' \
                'a defined (%{default_interval}) in a countable model (%{model}).',
      time_zone: 'The :on_time option should be defined with time zone, e.x.: ' \
                 'Time.zone.local(2014, 1, 1, 1, 1)'
    }

    attr_accessor :extra

    def initialize(*args)
      @msg, self.extra = args.flatten!
      super(@msg)
    end

    def to_s
      @msg.is_a?(Symbol) ? MESSAGES[@msg] % extra : super
    end
  end
end

require 'event_counter/active_record_extension'
ActiveRecord::Base.send(:include, EventCounter::ActiveRecordExtension)

if ActiveSupport::VERSION::MAJOR > 3
  require 'active_support/core_ext/time'
else
  require 'active_support/time'
end

# :nodoc:
class ActiveSupport::TimeWithZone
  def round_off(seconds = 60)
    Time.zone.at((to_f / seconds).round * seconds)
  end

  def floor(seconds = 60)
    Time.zone.at((to_f / seconds).floor * seconds)
  end
end

# :nodoc:
class String

  unless method_defined?(:squish!)
    # Stolen from Rails
    def squish!
      gsub!(/\A[[:space:]]+/, '')
      gsub!(/[[:space:]]+\z/, '')
      gsub!(/[[:space:]]+/, ' ')
      self
    end
  end

end
