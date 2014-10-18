EventCounter
===============

EventCounter is a database based event counter with throttling per time intervals.

Usage
-----

Let's define counters in model

```ruby
class Article < ActiveRecord::Base
  has_counter :views, interval: 5.minutes

  # :year, :month, :week and :day symbols are supported
  has_counter :views_by_week, interval: :week
end
```

Let's count...

```ruby
article = Article.create!

article.up!(:views)
# creates counter (if it doesn't exist) with value 1 and on Time.now() rounded to 5 minutes, e.x.:
#=> #<EventCounter id: 1, name: "views", value: 1, countable_id: 1, countable_type: "Article", created_at: "2014-10-16 23:20:00">

# at once
article.up!(:views, 3)
#=> #<EventCounter id: 1, name: "views", value: 4, countable_id: 1, countable_type: "Article", created_at: "2014-10-16 23:20:00">
# it will update counter (if the other exists in that interval) with value 3 and on Time.now() rounded to 5 minutes

# later
article.up!(:views, 5)
#=> #<EventCounter id: 2, name: "views", value: 5, countable_id: 1, countable_type: "Article", created_at: "2014-10-16 23:25:00">
article.down!(:views, 2)
#=> #<EventCounter id: 2, name: "views", value: 3, countable_id: 1, countable_type: "Article", created_at: "2014-10-16 23:25:00">

# anytime or in a background job
article.up!(:views, 7, on_time: 10.minutes.ago)
#=> #<EventCounter id: 3, name: "views", value: 7, countable_id: 1, countable_type: "Article", created_at: "2014-10-16 23:15:00">

# we have not got? let's fix it
article.up!(:views, 9, on_time: 10.minutes.ago, force: true)
#=> #<EventCounter id: 3, name: "views", value: 9, countable_id: 1, countable_type: "Article", created_at: "2014-10-16 23:15:00">
```

Let's get some statistics for our charts...

```ruby
article.data_for(:views)
#=> [[2014-10-16 23:15:00 +0400, 9], [2014-10-16 23:20:00 +0400, 4], [2014-10-16 23:25:00 +0400, 3]]

article.data_for(:views, interval: 10.minutes)
#=> [[2014-10-16 23:10:00 +0400, 9], [2014-10-16 23:20:00 +0400, 7]]

range = Time.mktime(2014, 10, 16, 23, 0)..Time.mktime(2014, 10, 16, 23, 10)
article.data_for(:views, interval: 10.minutes, range: range)
#=> [[2014-10-16 23:00:00 +0400, 0], [2014-10-16 23:10:00 +0400, 9]]

article.data_for(:views, interval: :day)
#=> [[2014-10-16 00:00:00 +0400, 16]]

article.data_for(:views, interval: :day, raw: true)
#=> [{"created_at" => "2014-10-16 00:00:00+04", "value" => "16"}]
# raw result will make difference in performance on a big data

# class wide
range = Time.mktime(2014, 10, 15)..Time.mktime(2014, 10, 16)
Article.data_for(:views, interval: :day, range: range)
#=> [[2014-10-15 00:00:00 +0400, 0], [2014-10-16 00:00:00 +0400, 16]]
```

Limitations
-----------

  - It works *ONLY* with *PostgreSQL* at the moment.
  - ActiveRecord 3+
  - It's polymorphic association.
  - Use it in production with caution because it's early release.


Installation
--------------

Add gem to Gemfile

```ruby
gem 'event_counter'
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

    add_index :event_counters, :countable_type
    add_index :event_counters,
      [:countable_type, :name, :countable_id], name: 'complex_index'

  end

end
```

License
----

MIT
