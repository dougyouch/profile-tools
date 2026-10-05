# frozen_string_literal: true

module ProfileTools
  # Totals for one profiled method within a single {Collector}.
  #
  # Duration, allocations and GC numbers include everything the method calls.
  # Recursive calls are counted in {#calls}, but only the outermost call is
  # measured, so a recursive method isn't counted twice.
  class MethodStats
    # @return [String] the method's display name, such as "User#save" or "User.find"
    attr_reader :method

    # @return [Integer] how many times the method was called
    attr_reader :calls

    # @return [Float] total time spent in the method, in milliseconds
    attr_reader :duration

    # @return [Integer] objects allocated while the method ran
    attr_reader :allocations

    # @return [Integer] garbage collections that ran while the method ran
    attr_reader :gc_count

    # @return [Integer] time spent in garbage collection while the method ran, in milliseconds
    attr_reader :gc_time

    # @return [Integer, nil] order in which the method was first called, nil until it is called
    attr_reader :sort_order

    # @param method [String] display name of the method
    def initialize(method)
      @method = method
      @calls = 0
      @duration = 0.0
      @allocations = 0
      @gc_count = 0
      @gc_time = 0
      @sort_order = nil
      @depth = 0
    end

    # @return [Boolean] true once the method has been called
    def called?
      @calls.positive?
    end

    # @return [Boolean] true while a call to the method is in progress, so a nested call is recursion
    def running?
      @depth.positive?
    end

    # Records the start of a call.
    #
    # @api private
    # @param sort_order [Integer] position to use if this is the method's first call
    # @return [void]
    def enter(sort_order)
      @sort_order ||= sort_order
      @calls += 1
      @depth += 1
    end

    # Records the end of a call.
    #
    # @api private
    # @return [void]
    def leave
      @depth -= 1
    end

    # Adds one measured call to the totals.
    #
    # @api private
    # @param duration [Float] milliseconds
    # @param allocations [Integer] objects allocated
    # @param gc_count [Integer] garbage collections
    # @param gc_time [Integer] milliseconds spent in garbage collection
    # @return [void]
    def add(duration, allocations, gc_count, gc_time)
      @duration += duration
      @allocations += allocations
      @gc_count += gc_count
      @gc_time += gc_time
    end

    # @return [Hash] the totals as a hash
    def to_h
      {
        method: method,
        calls: calls,
        duration: duration,
        allocations: allocations,
        gc_count: gc_count,
        gc_time: gc_time
      }
    end
  end
end
