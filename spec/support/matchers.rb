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

module RSpec
  module Matchers
    def eql_data(items)
      items.map! { |a, b| [ Time.zone.local(2014, 1, 1, 1, a), b ] }
      contain_exactly(*items)
    end
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
