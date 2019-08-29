# frozen_string_literal: true

class ProfileTools
  # Collects stats around method calls
  class Collector
    attr_reader :methods,
                :total_collection_calls

    def initialize
      @methods = {}
      @total_collection_calls = 0
    end

    def init_method(method)
      @methods[method] = {
        method: method,
        duration: 0.0,
        calls: 0,
        count_objects: Hash.new(0),
        num_collection_calls: 0,
        sort_order: nil
      }
    end

    def called_methods
      @methods
        .values
        .reject { |info| info[:calls].zero? }
        .sort { |a, b| b[:sort_order] <=> a[:sort_order] }
    end

    def instrument(method)
      current_collection_calls = @total_collection_calls
      result = nil
      duration = nil
      count_objects = ::ProfileTools.count_objects_around do
        started_at = now
        result = yield
        duration = now - started_at
      end
      add(
        method,
        duration * 1000.0,
        count_objects,
        @total_collection_calls - current_collection_calls
      )
      result
    end

    private

    def add(method, duration, count_object_changes, num_collection_calls)
      @total_collection_calls += 1
      @methods[method][:calls] += 1
      @methods[method][:sort_order] ||= @total_collection_calls
      @methods[method][:duration] += duration
      @methods[method][:num_collection_calls] = num_collection_calls
      add_object_changes(@methods[method][:count_objects], count_object_changes)
      adjust_count_objects(@methods[method][:count_objects], num_collection_calls)
    end

    def add_object_changes(current_objects, new_objects)
      new_objects.each do |name, cnt|
        current_objects[name] += cnt
      end
      current_objects
    end

    def adjust_count_objects(count_objects, num_collection_calls)
      return if num_collection_calls.zero?

      count_objects[:T_STRING] -= (1 * num_collection_calls)
      count_objects[:T_ARRAY] -= (1 * num_collection_calls)
      count_objects[:T_HASH] -= (2 * num_collection_calls)
    end

    def now
      Concurrent.monotonic_time
    end
  end
end
