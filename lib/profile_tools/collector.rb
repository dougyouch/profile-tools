# frozen_string_literal: true

class ProfileTools
  class Collector
    attr_reader :methods

    def initialize
      @methods = {}
    end

    def add(method, duration, count_object_changes)
      @methods[method] ||= {
        method: method,
        duration: 0.0,
        calls: 0,
        count_objects: Hash.new(0)
      }
      @methods[method][:calls] += 1
      @methods[method][:duration] += duration
      add_object_changes(@methods[method][:count_objects], count_object_changes)
    end

    private

    def add_object_changes(current_objects, new_objects)
      new_objects.each do |name, cnt|
        current_objects[name] += cnt
      end
      current_objects
    end
  end
end
