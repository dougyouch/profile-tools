# frozen_string_literal: true

require 'active_support'
require 'active_support/log_subscriber'

module ProfileTools
  # Writes one log line per called method when a profiling run finishes.
  #
  #   ProfileTools::LogSubscriber.attach_to :profile_tools
  #
  # The {Railtie} attaches it for you. Lines are logged at info level to
  # ActiveSupport::LogSubscriber.logger (Rails.logger in a Rails app).
  class LogSubscriber < ActiveSupport::LogSubscriber
    # Logs the stats of every method called during the run.
    #
    # @param event [ActiveSupport::Notifications::Event] carries the run's collector in its payload
    # @return [void]
    def profile(event)
      event.payload[:collector].called_methods.each do |stats|
        info { format_stats(stats) }
      end
    end
    subscribe_log_level :profile, :info

    private

    def format_stats(stats)
      "[ProfileTools] #{stats.method}: #{pluralize(stats.calls, 'call')}, #{stats.duration.round(3)}ms, " \
        "#{pluralize(stats.allocations, 'allocation')}, #{pluralize(stats.gc_count, 'GC run')} (#{stats.gc_time}ms)"
    end

    def pluralize(count, word)
      "#{count} #{count == 1 ? word : "#{word}s"}"
    end
  end
end
