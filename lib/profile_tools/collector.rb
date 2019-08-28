# frozen_string_literal: true

class ProfileTools
  class Collector
    attr_reader :methods

    def initialize
      @methods = {}
      @total_collection_calls = 0
    end

    def add(method, duration, count_object_changes)
      @methods[method] ||= {
        method: method,
        duration: 0.0,
        calls: 0,
        count_objects: Hash.new(0),
        num_collection_calls: @total_collection_calls
      }
      @methods[method][:calls] += 1
      @methods[method][:duration] += duration
      add_object_changes(@methods[method][:count_objects], count_object_changes, @total_collection_calls)
      @total_collection_calls += 1
    end

    private

    def add_object_changes(current_objects, new_objects, num_collection_calls)
      new_objects.each do |name, cnt|
        current_objects[name] += cnt
      end
      adjust_object_counts(current_objects, num_collection_calls) if num_collection_calls > 0
      current_objects
    end

    # :T_OBJECT=>1, :T_STRING=>6, :T_ARRAY=>3, :T_HASH=>8
    def adjust_object_counts(object_counts, num_collection_calls)
      object_counts[:T_OBJECT] -= (1 * num_collection_calls)
      object_counts[:T_STRING] -= (6 * num_collection_calls)
      object_counts[:T_ARRAY] -= (3 * num_collection_calls)
      object_counts[:T_HASH] -= (8 * num_collection_calls)
    end
  end
end
