# frozen_string_literal: true

require 'rubygems'
require 'bundler'
require 'stringio'

require 'simplecov'

SimpleCov.start do
  enable_coverage :branch
  # fail CI if any line or branch goes uncovered; skipped locally so single spec files can run
  minimum_coverage line: 100, branch: 100 if ENV['CI']

  cover 'lib/**/*.rb'
  # loaded by the gemspec spec through Gem::Specification.load, which SimpleCov doesn't track
  skip 'lib/profile_tools/version.rb'
end

begin
  Bundler.require(:default, :development, :spec)
rescue Bundler::BundlerError => e
  warn e.message
  warn 'Run `bundle install` to install missing gems'
  exit e.status_code
end

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
$LOAD_PATH.unshift(File.expand_path(__dir__))
require 'profile-tools'
require 'logger'
require 'support/simple_model'

RSpec.configure do |config|
  config.after do
    ProfileTools.stop_profiling!
  end
end
