# frozen_string_literal: true

module ProfileTools
  # Measures calls and adds them up per method for one profiling run (a request, a job, a block).
  #
  # Allocations are read from GC.stat(:total_allocated_objects), which only goes up, so the
  # counts stay exact when garbage collection runs mid-call. The counter is process-wide:
  # objects allocated by other threads at the same time are counted too.
  #
  # Nothing is allocated between the start and end readings, so a profiled method nested
  # inside another doesn't add to the outer method's count.
  class Collector
    # @return [Hash{String => MethodStats}] stats for every method seen by this collector
    attr_reader :stats

    # Creates the stats for the given methods up front. A method seen for the first time
    # inside another method's call allocates its {MethodStats}, which that outer call counts.
    #
    # @param method_names [Array<String>] display names of the profiled methods
    def initialize(method_names = [])
      @stats = {}
      @sort_order = 0
      method_names.each { |method| stats_for(method) }
    end

    # Runs the block and adds its time, allocations and garbage collection to the method's totals.
    # A call made while the same method is already running is counted but not measured again.
    #
    # @param method [String] display name of the method
    # @yield the code to measure
    # @return [Object] the block's result
    def instrument(method, &)
      stats = stats_for(method)
      recursive = stats.running?
      stats.enter(@sort_order += 1)
      begin
        recursive ? yield : measure(stats, &)
      ensure
        stats.leave
      end
    end

    # @return [Array<MethodStats>] the methods that were called, in the order they were first called
    def called_methods
      @stats.values.select(&:called?).sort_by(&:sort_order)
    end

    private

    def stats_for(method)
      @stats[method] ||= MethodStats.new(method)
    end

    def measure(stats)
      started_at = now
      allocations = allocated_objects
      gc_count = GC.count
      gc_time = GC.stat(:time)
      yield
    ensure
      stats.add(now - started_at, allocated_objects - allocations, GC.count - gc_count, GC.stat(:time) - gc_time)
    end

    def now
      Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_millisecond)
    end

    def allocated_objects
      GC.stat(:total_allocated_objects)
    end
  end
end
