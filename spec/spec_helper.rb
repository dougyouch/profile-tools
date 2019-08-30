# frozen_string_literal: true

require 'rubygems'
require 'bundler'
require 'securerandom'
require 'simplecov'
require 'stringio'

SimpleCov.start

begin
  Bundler.require(:default, :development, :spec)
rescue Bundler::BundlerError => e
  warn e.message
  warn 'Run `bundle install` to install missing gems'
  exit e.status_code
end

$LOAD_PATH.unshift(File.join(__FILE__, '../..', 'lib'))
$LOAD_PATH.unshift(File.expand_path('..', __FILE__))
require 'profile-tools'
require 'active_support/notifications'
require 'active_support/log_subscriber'
require 'logger'
require 'support/simple_model'

PROFILE_IO = StringIO.new
ActiveSupport::LogSubscriber.logger = Logger.new(PROFILE_IO)

NEW_OBJECT_PROC = Proc.new do |collector, num = 1|
  num.times { Object.new }
end

NESTED_INSTRUMENT_OBJECT_PROC = Proc.new do |collector, num = 1|
  NEW_OBJECT_PROC.call(collector, num)

  collector.instrument('level1') do
    NEW_OBJECT_PROC.call(collector, 3)
    5.times do
      collector.instrument('level2') do
        NEW_OBJECT_PROC.call(collector)
      end
    end
    NEW_OBJECT_PROC.call(collector, 2)
  end

  collector.instrument('level3') do
    collector.instrument('level4') do
      collector.instrument('level2') do
        NEW_OBJECT_PROC.call(collector)
      end
      collector.instrument('level5') do
        NEW_OBJECT_PROC.call(collector, 6)
      end
      NEW_OBJECT_PROC.call(collector)
    end
  end
end
