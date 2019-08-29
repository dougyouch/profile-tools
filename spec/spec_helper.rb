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

PROFILE_IO = StringIO.new
ActiveSupport::LogSubscriber.logger = Logger.new(PROFILE_IO)

NEW_OBJECT_PROC = Proc.new do
  Object.new
end
