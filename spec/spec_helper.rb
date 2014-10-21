require 'rubygems'
require 'bundler/setup'

require 'active_record'
require 'database_cleaner'
require 'logger'
require 'event_counter'

logfile_path = File.expand_path('../../log/test.log', __FILE__)
ActiveRecord::Base.logger = Logger.new(logfile_path)

conf_local = File.expand_path('../../config/database.yml', __FILE__)
conf_ci = File.expand_path('../../config/database.ci.yml', __FILE__)

# Assume Travis CI database config if no custom one exists
conf = File.exist?(conf_local) ? conf_local : conf_ci

YAML.load(File.open(conf).read).values.each do |config|
  ActiveRecord::Base.establish_connection config
end

ActiveRecord::Base.default_timezone = :utc
Time.zone = 'Moscow'

ActiveRecord::Schema.define do
  self.verbose = false

  create_table :balls, force: true

  create_table :event_counters, force: true do |t|
    t.string :name, null: false
    t.integer :value, default: 0, null: false
    t.references :countable, polymorphic: true, null: false

    t.datetime :created_at
  end

  add_index :event_counters, :created_at#, name: 'idx_created_at_desc'
  add_index :event_counters, [:countable_type, :name, :countable_id],
    name: 'idx_composite'
end

# :nodoc:
class Ball < ActiveRecord::Base
  event_counter_for :rotations, 5.minutes
  event_counter_for :rotations_by_week, :week
  event_counter_for :rotations_by_month, :month
  event_counter_for :rotations_by_year, :year
  event_counter_for :rotations_by_two_year, 2.years
end

Dir[File.expand_path('../support/*.rb', __FILE__)].each do |file|
  require file
end

RSpec.configure do |config|

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning { example.run }
  end

  config.filter_run_excluding slow: true unless ENV['RUN_ALL']
end
