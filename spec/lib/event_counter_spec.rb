require 'spec_helper'

describe EventCounter do
  let(:ball) { Ball.create! }

  it 'has version' do
    expect(EventCounter::VERSION).to match(/\d+\.\d+\.\d+/)
  end

  it '#make' do
    expect {
      counter = ball.rotations.make(3)
      expect(counter).to be_a(EventCounter)

      expected = {
        countable_id: ball.id,
        countable_type: ball.class.name,
        created_at: Time.zone.now.floor(300),
        name: 'rotations',
        value: 3
      }.with_indifferent_access

      counter.attributes.except('id').keys.each do |attr|
        expect(counter[attr]).to be_eql(expected[attr])
      end
    }.to change { EventCounter.count }.by(1)
  end

  it '#make on time' do
    on_time = Time.zone.local(2014, 1, 1, 1, 14)
    expect {
      counter = ball.rotations.make(
        3, on_time: on_time)
      expect(counter).to be_a(EventCounter)

      expected = {
        countable_id: ball.id,
        countable_type: ball.class.name,
        created_at: on_time.change(min: 10),
        name: 'rotations',
        value: 3
      }.with_indifferent_access

      counter.attributes.except('id').keys.each do |attr|
        expect(counter[attr]).to be_eql(expected[attr])
      end
    }.to change { EventCounter.count }.by(1)
  end

  it '#make on time with interval as symbol' do
    on_time = Time.zone.local(2014, 1, 1, 1, 1)
    [:week, :month, :year].each do |interval|
      expect {
        counter = ball.send(:"rotations_by_#{interval}").make(
          3, on_time: on_time)
        expect(counter).to be_a(EventCounter)

        expected = {
          countable_id: ball.id,
          countable_type: ball.class.name,
          created_at: on_time.send(:"beginning_of_#{interval}"),
          name: "rotations_by_#{interval}",
          value: 3
        }.with_indifferent_access

        counter.attributes.except('id').keys.each do |attr|
          expect(counter[attr]).to be_eql(expected[attr])
        end
      }.to change { EventCounter.count }.by(1)
      expect(
        ball.data_for(:"rotations_by_#{interval}").last.last
      ).to eql(3)
    end

  end

end

describe Ball do
  let(:ball) { Ball.create! }

  shared_examples 'default behavior' do

    it 'creates a new counter while incrementing' do
      expect {
        expect(ball.up!(:rotations)).to be_a(EventCounter)
      }.to change { EventCounter.count }.by(1)

      on_time = Time.zone.local(2011, 11, 11, 11, 11)
      expect {
        expect(ball.up!(:rotations, on_time: on_time))
          .to be_a(EventCounter)
      }.to change { EventCounter.count }.by(1)

      on_time = Time.zone.local(2012, 12, 12, 12, 12)
      expect {
        expect(ball.up!(:rotations, 5, on_time: on_time))
          .to be_a(EventCounter)
      }.to change { EventCounter.count }.by(1)
    end

    it 'creates a new counter while decrementing' do
      expect {
        expect(ball.down!(:rotations)).to be_a(EventCounter)
      }.to change { EventCounter.count }.by(1)

      on_time = Time.zone.local(2011, 11, 11, 11, 11)
      expect {
        expect(ball.down!(:rotations, on_time: on_time))
          .to be_a(EventCounter)
      }.to change { EventCounter.count }.by(1)

      on_time = Time.zone.local(2012, 12, 12, 12, 12)
      expect {
        expect(ball.down!(:rotations, 5, on_time: on_time))
          .to be_a(EventCounter)
      }.to change { EventCounter.count }.by(1)
    end

    it 'increments existent counter with default value' do
      counter = ball.rotations.make

      expect {
        expect {
          expect(ball.up!(:rotations)).to be_a(EventCounter)
        }.to change { counter.reload.value }.from(1).to(2)
      }.to_not change { EventCounter.count }
    end

    it 'decrements existent counter with default value' do
      counter = ball.rotations.make(- 1)

      expect {
        expect {
          expect(ball.down!(:rotations)).to be_a(EventCounter)
        }.to change { counter.reload.value }.from(-1).to(-2)
      }.to_not change { EventCounter.count }
    end

    it 'increments existent counter by a specified value' do
      counter = ball.rotations.make

      expect {
        expect {
          expect(ball.up!(:rotations, 3)).to be_a(EventCounter)
        }.to change { counter.reload.value }.from(1).to(4)
      }.to_not change { EventCounter.count }
    end

    it 'decrements existent counter by a specified value' do
      counter = ball.rotations.make 3

      expect {
        expect {
          expect(ball.down!(:rotations, 5)).to be_a(EventCounter)
        }.to change { counter.reload.value }.from(3).to(-2)
      }.to_not change { EventCounter.count }
    end

    it 'increments existent counter on time with default value' do
      on_time = Time.zone.local(2012, 12, 12, 12, 12)
      counter = ball.rotations.make on_time: on_time

      expect {
        expect {
          expect(ball.up!(:rotations, on_time: on_time.change(min: 14)))
        }.to change { counter.reload.value }.from(1).to(2)
      }.to_not change { EventCounter.count }
    end

    it 'decrements existent counter on time with default value' do
      on_time = Time.zone.local(2012, 12, 12, 12, 12)
      counter = ball.rotations.make on_time: on_time

      expect {
        expect {
          expect(ball.down!(:rotations, on_time: on_time.change(min: 14)))
        }.to change { counter.reload.value }.from(1).to(0)
      }.to_not change { EventCounter.count }
    end

    it 'increments existent counter on time with specified value' do
      on_time = Time.zone.local(2012, 12, 12, 12, 12)
      counter = ball.rotations.make 2, on_time: on_time

      expect {
        expect {
          expect(ball.up!(:rotations, 3, on_time: on_time.change(min: 14)))
        }.to change { counter.reload.value }.from(2).to(5)
      }.to_not change { EventCounter.count }
    end

    it 'decrements existent counter on time with specified value' do
      on_time = Time.zone.local(2012, 12, 12, 12, 12)
      counter = ball.rotations.make 2, on_time: on_time

      expect {
        expect {
          expect(ball.down!(:rotations, 3, on_time: on_time.change(min: 14)))
        }.to change { counter.reload.value }.from(2).to(-1)
      }.to_not change { EventCounter.count }
    end

    it 'forces existent counter with new value' do
      counter = ball.rotations.make

      expect {
        expect {
          expect(ball.rotations.make(5, force: true))
            .to be_a(EventCounter)
        }.to change { counter.reload.value }.from(1).to(5)
      }.to_not change { EventCounter.count }
    end

    it 'forces existent counter on time with new value' do
      on_time = Time.zone.local(2012, 12, 12, 12, 12)
      counter = ball.rotations.make 2, on_time: on_time

      expect {
        expect {
          expect(ball.rotations.make(5, force: true, on_time: on_time))
            .to be_a(EventCounter)
        }.to change { counter.reload.value }.from(2).to(5)
      }.to_not change { EventCounter.count }
    end

    it 'raises error on wrong direction foc counter' do
      expect { ball.send(:rotate_counter, *[:rotations, vector: :wrong_direction]) }
        .to raise_error(EventCounter::CounterError, /wrong direction/i)
    end

    it 'raises error on unable to find counter' do
      expect { ball.up!(:unknown) }
        .to raise_error(EventCounter::CounterError, /unable to find/i)
    end

    def setup_counters(countable_count = 1)
      [1, 1, 2, 3, 5, 8, 13, 21, 34].each do |n|
        on_time = Time.zone.local(2014, 1, 1, 1, n)
        if countable_count == 1
          ball.rotations.make n, on_time: on_time
        else
          countable_count.times do
            Ball.create!.rotations.make n, on_time: on_time
          end
        end
      end
    end

    context '.data_for' do

      subject { Ball }

      before { setup_counters(3) }

      it 'with a default interval' do
        data = [
          # [ minute, value ]
          [ 0, 21 ],
          [ 5, 39 ],
          [ 10, 39 ],
          [ 15, 0 ],
          [ 20, 63 ],
          [ 25, 0 ],
          [ 30, 102 ]
        ]
        expect(subject.data_for(:rotations)).to eql_data(data)
      end

      it 'with a greater interval' do
        data = [ [ 0, 60 ], [ 10, 39 ], [ 20, 63 ], [ 30, 102 ] ]

        expect(subject.data_for(:rotations, interval: 10.minutes))
          .to eql_data(data)
      end

      it 'with a greater interval within range' do
        data = [ [ 10, 39 ], [ 20, 63 ] ]

        range_start = Time.zone.local(2014, 1, 1, 1, 15)
        range_end = Time.zone.local(2014, 1, 1, 1, 29)
        range = range_start..range_end

        expect(subject.data_for(:rotations, interval: 10.minutes, range: range))
          .to eql_data(data)
      end

      it 'with a greater interval as symbol and a simple data' do
        bmonth = Time.zone.local(2014, 1, 1).beginning_of_month
        data = [ [ bmonth, 264 ] ]

        expect(subject.data_for(:rotations, interval: :month))
          .to match_array(data)
      end

      it 'with a greater interval as symbol and a simple data within range' do
        bmonth = Time.zone.local(2014, 1, 1).beginning_of_month
        data = [ [ bmonth, 264 ] ]

        range_start = bmonth
        range_end = bmonth.end_of_month
        range = range_start..range_end

        expect(subject.data_for(:rotations, interval: :month, range: range))
          .to match_array(data)
      end


      it 'with a greater interval as symbol on large data set within range' do
        EventCounter.all.each do |counter|
          11.times do |x|
            created_at = counter.created_at - (x + 1).months
            EventCounter.create!(counter.attributes.except('id')) do |c|
              c.created_at = created_at
            end
          end
        end

        data = (6..12).map { |x| [ Time.zone.local(2013, x), 264 ] }
        range_start = data[0][0].beginning_of_month
        range_end = data[-1][0].end_of_month
        range = range_start..range_end

        expect(subject.data_for(:rotations, interval: :month, range: range))
          .to match_array(data)
      end

    end

    context '#data_for' do

      before { setup_counters }

      it 'with default interval' do
        data = [
          # [ minute, value ]
          [ 0, 7   ],
          [ 5, 13  ],
          [ 10, 13 ],
          [ 15, 0  ],
          [ 20, 21 ],
          [ 25, 0  ],
          [ 30, 34 ]
        ]
        expect(ball.data_for(:rotations)).to eql_data(data)
      end

      it 'with a less interval' do
        expect { ball.data_for(:rotations, interval: 3.minutes) }
          .to raise_error(EventCounter::CounterError, /could not be less/i)

        [:week, :month, :year].each do |interval|
          expect { ball.data_for(:rotations_by_two_year, interval: interval) }
            .to raise_error(EventCounter::CounterError, /could not be less/i)
        end
      end

      it 'with a interval which is not a multiple of original interval' do
        expect { ball.data_for(:rotations, interval: 7.minutes) }
          .to raise_error(EventCounter::CounterError, /multiple of/i)
      end

      it 'with a greater interval' do
        data = [ [ 0, 33 ], [ 20, 55 ] ]

        expect(ball.data_for(:rotations, interval: 20.minutes))
          .to eql_data(data)
      end

      it 'with a greater interval on random (min/max) time period' do
        EventCounter.order("created_at").limit(4).to_a.map(&:destroy)

        data = [ [ 0, 26 ], [ 20, 55 ] ]

        expect(ball.data_for(:rotations, interval: 20.minutes))
          .to eql_data(data)
      end

      it 'with a greater interval and a time range' do
        range_start = Time.zone.local 2014, 1, 1, 1, 15
        range_end =   Time.zone.local 2014, 1, 1, 1, 45
        range = range_start.in_time_zone..range_end.in_time_zone

        data = [ [ 10, 13 ], [ 20, 21 ], [ 30, 34 ], [ 40, 0] ]

        expect(ball.data_for(:rotations, interval: 10.minutes, range: range))
          .to eql_data(data)
      end

      it 'with a greater interval as symbol' do
        beginning_of_week = Time.zone.local(2014).beginning_of_week

        data = [ [ beginning_of_week, 88 ] ]

        expect(ball.data_for(:rotations, interval: :week))
          .to eql(data)
      end

    end

  end

  it_has 'default behavior'

  context "with AR.default_timezone set to :local" do
    before { ActiveRecord::Base.default_timezone = :local }
    after  { ActiveRecord::Base.default_timezone = :utc   }

    it_has 'default behavior'
  end

  context "with different timezone" do
    before { Time.zone = 'Pacific Time (US & Canada)' }
    after  { Time.zone = 'Moscow'                     }

    it_has 'default behavior'
  end

  context "with AR.default_timezone set to :local and different timezone" do
    before do
      ActiveRecord::Base.default_timezone = :local
      Time.zone = 'Pacific Time (US & Canada)'
    end
    after do
      Time.zone = 'Moscow'
      ActiveRecord::Base.default_timezone = :utc
    end

    it_has 'default behavior'
  end

  context 'in timezone with DST' do

    it 'starts PST -> PDT (+1 hour), offset after UTC-7h' do
      Time.zone = 'UTC'

      # DST for US/Pacific in UTC
      dst_before = Time.zone.local(2014, 3, 9, 9, 59)
      dst_after  = Time.zone.local(2014, 3, 9, 10, 1)

      ball.rotations.make(1, on_time: dst_before)
      ball.rotations.make(1, on_time: dst_after)

      Time.zone = 'Pacific Time (US & Canada)'
      data = [
        [ Time.zone.local(2014, 3, 9, 1), 1 ],
        [ Time.zone.local(2014, 3, 9, 3), 1 ],
      ]

      expect(ball.data_for(:rotations, interval: 1.hour)).to eql(data)

      range = dst_before..dst_after
      expect(ball.data_for(:rotations, interval: 1.hour, range: range))
        .to eql(data)
    end

    it 'ends PDT -> PST (-1 hour), offset after UTC-8h' do
      Time.zone = 'UTC'

      # DST for US/Pacific in UTC
      dst_before = Time.zone.local(2014, 11, 2, 8, 59)
      dst_after  = Time.zone.local(2014, 11, 2, 9, 1)

      ball.rotations.make(1, on_time: dst_before)
      ball.rotations.make(1, on_time: dst_after)

      Time.zone = 'Pacific Time (US & Canada)'
      data = [
        [ Time.zone.local(2014, 11, 2, 1), 1 ],
        [ Time.utc(2014, 11, 2, 9).in_time_zone, 1 ],
      ]

      expect(ball.data_for(:rotations, interval: 1.hour)).to eql(data)

      range = dst_before..dst_after
      expect(ball.data_for(:rotations, interval: 1.hour, range: range))
        .to eql(data)
    end
  end
end
