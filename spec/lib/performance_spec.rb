require 'spec_helper'

describe Ball, slow: true do

  before(:suite) do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.clean_with(:truncation)
  end

  let(:range_start) { Time.zone.local(2013, 7).beginning_of_month }
  let(:range_end)   { Time.zone.local(2014, 6).end_of_month       }
  let(:range)       { range_start..range_end }

  def disable_logging(&blk)
    logger = ActiveRecord::Base.logger
    ActiveRecord::Base.logger = nil
    yield
    ActiveRecord::Base.logger = logger
  end


  def connection
    ActiveRecord::Base.connection.raw_connection
  end

  def setup_data(countable = 1000, step = 1.day)

    ball = Ball.create!

    (Time.zone.local(2012).to_i..Time.zone.local(2015).to_i).step(step) do |i|
      on_time = Time.zone.at(i)
      ball.rotations.make on_time: on_time
    end

    path = File.expand_path('../../fixtures/event_counters.sql', __FILE__)

    skip_count = 0

    export_sql = "COPY event_counters TO STDOUT (DELIMITER '|')"
    connection.copy_data(export_sql) do
      File.open(path, 'w') do |f|
        while line = connection.get_copy_data
          skip_count += 1
          f.write(line)
        end
      end
    end

    File.open(path, 'a+') do |f|
      lines = f.readlines
      last_ids = lines.last.split('|')[0, 4]
      id, countable_id = last_ids.first.to_i, last_ids.last.to_i
      (2..countable).each do |i|
        countable_id += 1
        lines.each do |line|
          id += 1
          split = line.split('|')
          split[0] = id
          split[3] = countable_id
          f.write split.join('|')
        end
      end
    end

    import_sql = "COPY event_counters FROM STDIN (DELIMITER '|')"
    connection.copy_data(import_sql) do
      File.open(path, 'r') do |f|
        i = 0
        while line = f.gets
          i += 1
          next if i <= skip_count
          connection.put_copy_data line
        end
      end
    end
  end

  context '#data_for' do

    it 'performance is adequate' do
      disable_logging { setup_data }

      data = [
        {"created_at"=>"2013-07-01 00:00:00", "value"=>"31000"},
        {"created_at"=>"2013-08-01 00:00:00", "value"=>"31000"},
        {"created_at"=>"2013-09-01 00:00:00", "value"=>"30000"},
        {"created_at"=>"2013-10-01 00:00:00", "value"=>"31000"},
        {"created_at"=>"2013-11-01 00:00:00", "value"=>"30000"},
        {"created_at"=>"2013-12-01 00:00:00", "value"=>"31000"},
        {"created_at"=>"2014-01-01 00:00:00", "value"=>"31000"},
        {"created_at"=>"2014-02-01 00:00:00", "value"=>"28000"},
        {"created_at"=>"2014-03-01 00:00:00", "value"=>"31000"},
        {"created_at"=>"2014-04-01 00:00:00", "value"=>"30000"},
        {"created_at"=>"2014-05-01 00:00:00", "value"=>"31000"},
        {"created_at"=>"2014-06-01 00:00:00", "value"=>"30000"}
      ]

      #expect {
        expect(
          Ball.data_for(:rotations, interval: :month, range: range, raw: true)
        ).to match_array(data)
      #}.to take_less_than(0.1).seconds
    end
  end
end
