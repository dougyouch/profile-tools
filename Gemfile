# frozen_string_literal: true

source 'http://rubygems.org'

activesupport_version =
  case ENV['RUBY_VERSION']
  when /1\.9\.3/
    3
  when /2\.1\.9/
    4
  else
    5
  end

gem 'activesupport', "~> #{activesupport_version}"

group :development do
  gem 'rake'
  gem 'rubocop'
end

group :spec do
  gem 'rspec'
  gem 'simplecov'
end
