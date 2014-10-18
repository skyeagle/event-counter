require 'spec_helper'

describe Ball, performance: true do

  let(:range_start) { (Time.mktime 2011, 12).beginning_of_month }
  let(:range_end)   { (Time.mktime 2012, 11).end_of_month }
  let(:range)       { range_start..range_end }

  before(:all) do
    @logger = ActiveRecord::Base.logger
    ActiveRecord::Base.logger = nil
  end

  after(:all) do
    ActiveRecord::Base.logger = @logger
  end

  def setup_data(countable = 10, step = 1.day)
    (1..countable).map do |x|
      ball = Fabricate(:ball)

      (range_start.to_i..range_end.to_i).step(step) do |i|
        on_time = Time.at(i)
        ball.rotations.make on_time: on_time
      end
    end
  end

  context '#data_for' do

    before { setup_data }

    it 'performance is adequate' do
      data = [
        {"created_at"=>"2011-12-01 00:00:00+04", "value"=>"310"},
        {"created_at"=>"2012-01-01 00:00:00+04", "value"=>"310"},
        {"created_at"=>"2012-02-01 00:00:00+04", "value"=>"290"},
        {"created_at"=>"2012-03-01 00:00:00+04", "value"=>"310"},
        {"created_at"=>"2012-04-01 00:00:00+04", "value"=>"300"},
        {"created_at"=>"2012-05-01 00:00:00+04", "value"=>"310"},
        {"created_at"=>"2012-06-01 00:00:00+04", "value"=>"300"},
        {"created_at"=>"2012-07-01 00:00:00+04", "value"=>"310"},
        {"created_at"=>"2012-08-01 00:00:00+04", "value"=>"310"},
        {"created_at"=>"2012-09-01 00:00:00+04", "value"=>"300"},
        {"created_at"=>"2012-10-01 00:00:00+04", "value"=>"310"},
        {"created_at"=>"2012-11-01 00:00:00+04", "value"=>"300"}
      ]

      expect {
        expect(Ball.data_for(:rotations, interval: :month, range: range, raw: true))
          .to eql(data)
      }.to take_less_than(0.1).seconds
    end
  end
end
