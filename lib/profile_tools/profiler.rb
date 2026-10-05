# frozen_string_literal: true

require 'active_support'
require 'active_support/notifications'

module ProfileTools
  # Tracks the profiling run on the current thread (fiber-local, through Thread.current).
  #
  # The outermost {#instrument} call starts a run: it creates a {Collector} and publishes it in
  # a "profile.profile_tools" ActiveSupport notification once the block finishes. Calls made
  # during the run add to that collector.
  class Profiler
    # Name used by {ProfileTools.instrument} when none is given
    DEFAULT_NAME = 'ProfileTools.instrument'

    # @return [Collector, nil] the collector of the current run, or of the last finished run
    attr_reader :collector

    def initialize
      @collector = nil
      @running = false
    end

    # Measures the block as the named method. Starts a new run if none is in progress.
    #
    # @param name [String] display name to record the block under
    # @yield the code to measure
    # @return [Object] the block's result
    def instrument(name = DEFAULT_NAME, &)
      return @collector.instrument(name, &) if running?

      run(name, &)
    end

    # @return [Boolean] true while a run is in progress
    def running?
      @running
    end

    private

    def run(name, &)
      @running = true
      @collector = Collector.new(ProfileTools.profiled_methods)
      ActiveSupport::Notifications.instrument(EVENT, name: name, collector: @collector) do
        @collector.instrument(name, &)
      end
    ensure
      @running = false
    end
  end
end
