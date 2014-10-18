%w(3.0 3.1 3.2 4.0 4.1).each do |ar_version|
  %w(pg).each do |db_type|
    appraise "#{db_type}-ar-#{ar_version.split('.').first(2).join}" do
      gem 'activerecord', "~> #{ar_version}"
      gem 'activesupport', "~> #{ar_version}"
      gem 'database_cleaner'
      gem 'pg'
      gem 'rspec'
    end
  end
end
