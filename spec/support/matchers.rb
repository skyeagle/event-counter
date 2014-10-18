RSpec::Matchers.define :be_eql do |expected|
  match do |actual|
    if expected.is_a?(Time)
      expect(expected.strftime('%d-%m-%Y %H:%M:%S'))
        .to eq(actual.strftime('%d-%m-%Y %H:%M:%S'))
    else
      expect(expected).to eql(actual)
    end
  end

  diffable
end

RSpec::Matchers.define :eql_data do |expected|
  match do |actual|
    expected.map! { |a, b| [ Time.mktime(2012, 12, 12, 12, a), b ] }
    expect(actual).to eql(expected)
  end
end

require 'benchmark'

RSpec::Matchers.define :take_less_than do |expected|
  chain :seconds do; end
  match do |block|
    elapsed = Benchmark.realtime { block.call }
    elapsed <= expected
  end

  supports_block_expectations
end
