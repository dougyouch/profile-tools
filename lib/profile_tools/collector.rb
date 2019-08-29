# frozen_string_literal: true

class ProfileTools
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
        num_collection_calls: 0
      }
    end

    def add(method, duration, count_object_changes, num_collection_calls)
      @total_collection_calls += 1
      @methods[method][:calls] += 1
      @methods[method][:duration] += duration
      @methods[method][:num_collection_calls] = num_collection_calls
      add_object_changes(@methods[method][:count_objects], count_object_changes)
      adjust_object_counts(@methods[method][:count_objects], num_collection_calls) if num_collection_calls > 0
    end

    private

    def add_object_changes(current_objects, new_objects)
      new_objects.each do |name, cnt|
        current_objects[name] += cnt
      end
      current_objects
    end

    # :T_OBJECT=>1, :T_STRING=>6, :T_ARRAY=>3, :T_HASH=>6
    def adjust_object_counts(object_counts, num_collection_calls)
      object_counts[:T_OBJECT] -= (1 * num_collection_calls)
      object_counts[:T_STRING] -= (6 * num_collection_calls)
      object_counts[:T_ARRAY] -= (3 * num_collection_calls)
      object_counts[:T_HASH] -= (5 * num_collection_calls)
    end
  end
end
