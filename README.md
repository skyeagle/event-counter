[![Build Status](https://travis-ci.org/skyeagle/event-counter.svg)](https://travis-ci.org/skyeagle/event-counter)

# EventCounter

EventCounter is a database based event counter with throttling per time intervals.

## Usage

Let's define counters in model

```ruby
class Article < ActiveRecord::Base
  has_counter :views, interval: 5.minutes # default interval is :day

  # :year, :month, :week and :day symbols are supported
  has_counter :views_by_week, interval: :week
end
```

Let's count...

```ruby
article = Article.create!

article.up!(:views)
# => #<EventCounter id: 1, name: "views", value: 1, countable_id: 1,
# countable_type: "Article", created_at: "2014-10-16 23:20:00">
# creates counter (if it doesn't exist) with value 1 and on Time.now() rounded
# to 5 minutes, e.x.:

# at once
article.up!(:views, 3)
# => #<EventCounter id: 1, name: "views", value: 4, countable_id: 1,
# countable_type: "Article", created_at: "2014-10-16 23:20:00">
# Updates counter (if the other exists in that interval) with value 3 and
# on Time.now() rounded to 5 minutes

# later
article.up!(:views, 5)
# => #<EventCounter id: 2, name: "views", value: 5, countable_id: 1,
# countable_type: "Article", created_at: "2014-10-16 23:25:00">
article.down!(:views, 2)
# => #<EventCounter id: 2, name: "views", value: 3, countable_id: 1,
# countable_type: "Article", created_at: "2014-10-16 23:25:00">

# anytime or in a background job
article.up!(:views, 7, on_time: 10.minutes.ago.in_time_zone)
# => #<EventCounter id: 3, name: "views", value: 7, countable_id: 1,
# countable_type: "Article", created_at: "2014-10-16 23:15:00">

# we have not got? let's fix it
article.up!(:views, 9, on_time: 10.minutes.ago.in_time_zone, force: true)
# => #<EventCounter id: 3, name: "views", value: 9, countable_id: 1,
# countable_type: "Article", created_at: "2014-10-16 23:15:00">
```

Let's get some statistics for our charts...

```ruby
article.data_for(:views)
# => [
# [Thu, 16 Oct 2014 23:15:00 MSK +04:00, 9],
# [Thu, 16 Oct 2014 23:20:00 MSK +04:00, 4],
# [Thu, 16 Oct 2014 23:25:00 MSK +04:00, 3]
# ]

article.data_for(:views, interval: 10.minutes)
# => [
# [Thu, 16 Oct 2014 23:10:00 MSK +04:00, 9],
# [Thu, 16 Oct 2014 23:20:00 MSK +04:00, 7]
# ]

# with range
range_start = Time.zone.local(2014, 10, 16, 23, 0)
range_end   = Time.zone.local(2014, 10, 16, 23, 10)
range = range_start..range_end
article.data_for(:views, interval: 10.minutes, range: range)
#=> [
# [Thu, 16 Oct 2014 23:00:00 MSK +04:00, 0]
# [Thu, 16 Oct 2014 23:10:00 MSK +04:00, 9]
# ]

# for different time zone (although we have no data for that time)
range_start = Time.zone.local(2014, 10, 16, 23, 0).in_time_zone('UTC')
range_end   = Time.zone.local(2014, 10, 16, 23, 10).in_time_zone('UTC')
range = range_start..range_end
article.data_for(:views, interval: 10.minutes, range: range, tz: 'UTC')
#=> [
# [Thu, 16 Oct 2014 23:00:00 UTC +00:00, 0] 
# [Thu, 16 Oct 2014 23:10:00 UTC +00:00, 0]
# ]

article.data_for(:views, interval: :day)
# => [Thu, 16 Oct 2014 00:00:00 MSK +04:00, 16]

article.data_for(:views, interval: :day, raw: true)
#=> [{"created_at" => "2014-10-16 00:00:00", "value" => "16"}]
# The raw result will make difference in performance on a big data.
# The returned time is in the requested time zone. By default, a normalization
# looks as `Time.zone.parse(i['created_at']), i['value'].to_i ]`

# class wide
range_start = Time.zone.local(2014, 10, 15)
range_end   = Time.zone.local(2014, 10, 16)
range = range_start..range_end
Article.data_for(:views, interval: :day, range: range)
# => [
# [Thu, 15 Oct 2014 00:00:00 MSK +04:00, 0]
# [Thu, 16 Oct 2014 00:00:00 MSK +04:00, 16]
# ]
```

## Limitations

  - It works *ONLY* with *PostgreSQL* at the moment.
  - Ruby 2+
  - ActiveRecord 3+
  - ActiveSupport 3+
  - It's polymorphic association.
  - It uses ActiveSupport::TimeWithZone to return user friendly statistics.
    So, you have to operate with dates with time zones.
  - Use it in production with caution because it's early release.


## Installation

Add gem to Gemfile

```ruby
gem 'event-counter'
```

Create migration `rails g migration create_event_counters` with the
following code:

```ruby
class CreateEventCounters < ActiveRecord::Migration

  def change
    create_table :event_counters, force: true do |t|
      t.string :name, null: false
      t.integer :value, default: 0, null: false
      t.references :countable, polymorphic: true, null: false

      t.datetime :created_at
    end

    add_index :event_counters, :created_at
    add_index :event_counters,
      [:countable_type, :name, :countable_id], name: 'index_complex'

  end

end
```

License
----

MIT
