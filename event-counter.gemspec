# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'event_counter/version'

Gem::Specification.new do |spec|
  spec.name          = 'event-counter'
  spec.version       = EventCounterVersion::VERSION
  spec.authors       = ['Anton Orel']
  spec.email         = ['eagle.anton@gmail.com']
  spec.summary       = 'Event counter with throttling per time interval'
  spec.description   = 'Database based event counter with throttling per time intervals'
  spec.homepage      = 'https://github.com/skyeagle/event-counter'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(/^bin\//) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(/^(test|spec|features)\//)
  spec.require_paths = ['lib']

  spec.add_dependency 'activerecord', '~> 3'
  spec.add_dependency 'pg', '~> 0'

  spec.add_development_dependency 'bundler', '~> 1.7'
  spec.add_development_dependency 'database_cleaner', '~> 0'
  spec.add_development_dependency 'rspec', '~> 3'
  spec.add_development_dependency 'fabrication', '~> 0'
  spec.add_development_dependency 'rake', '~> 10.0'
end
