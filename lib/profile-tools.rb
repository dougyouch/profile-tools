# frozen_string_literal: true

class ProfileTools
  autoload :AggregateLogSubscriber, 'profile_tools/aggregate_log_subscriber'
  autoload :Collector, 'profile_tools/collector'
  autoload :LogSubscriber, 'profile_tools/log_subscriber'

  def initialize
    ObjectSpace.count_objects
  end

  def profile_instance_method(class_name, method_name)
    profile_method(Object.const_get(class_name), class_name, method_name, "#{class_name}##{method_name}")
  end

  def profile_class_method(class_name, method_name)
    profile_method(Object.const_get(class_name).singleton_class, class_name, method_name, "#{class_name}.#{method_name}")
  end

  def self.load(yaml_file)
    require 'yaml'
    profile(YAML.load_file(yaml_file))
  end

  def self.profile(classes)
    profile_tools = new

    classes.each do |class_name, methods|
      methods.each do |method_name|
        if method_name =~ /\A\./
          profile_tools.profile_class_method(class_name, method_name[1, method_name.size])
        else
          profile_tools.profile_instance_method(class_name, method_name)
        end
      end
    end

    profile_tools
  end

  def self.count_objects_changes(starting_objects, new_objects)
    changes = {}
    new_objects.each do |name, cnt|
      old_cnt = starting_objects[name]
      old_cnt += 1 if name == :T_HASH
      diff = cnt - old_cnt
      changes[name] = diff if diff != 0
    end
    changes
  end

  def self.count_objects_around
    starting_objects = ObjectSpace.count_objects
    yield
    ::ProfileTools.count_objects_changes(starting_objects, ObjectSpace.count_objects)
  end

  def self.instrument
    ::ProfileTools.increment_call_depth
    collector = ::ProfileTools.collector
    current_collection_calls = collector.total_collection_calls
    ActiveSupport::Notifications.instrument('method.profile_tools', class_name: name, method: 'instrument', display_name: '#{name}.instrument', collector: collector) do |payload|
      result = nil
      payload[:count_objects] = ::ProfileTools.count_objects_around do
        result = yield
      end
      payload[:call_depth] = ::ProfileTools.decrement_call_depth
      payload[:num_collection_calls] = collector.total_collection_calls - current_collection_calls
      result
    end
  end

  def self.increment_call_depth
    Thread.current[:profile_tools_call_depth] ||= 0
    Thread.current[:profile_tools_call_depth] += 1
  end

  def self.decrement_call_depth
    Thread.current[:profile_tools_call_depth] -= 1
  end

  def self.collector
    Thread.current[:profile_tools_collector] ||= Collector.new
  end

  def self.reset_collector
    Thread.current[:profile_tools_collector] = nil
  end

  private

  def profile_method(kls, class_name, method_name, display_name)
    method_name_without_profiling = generate_method_name(method_name.to_s, 'without_profiling')
    method_name_with_profiling = generate_method_name(method_name.to_s, 'with_profiling')

    kls.class_eval(
<<-STR, __FILE__, __LINE__ + 1
def #{method_name_with_profiling}(*args)
  ::ProfileTools.increment_call_depth
  collector = ::ProfileTools.collector
  current_collection_calls = collector.total_collection_calls
  ActiveSupport::Notifications.instrument('method.profile_tools', class_name: '#{class_name}', method: '#{method_name}', display_name: '#{display_name}', collector: collector) do |payload|
    result = nil
    payload[:count_objects] = ::ProfileTools.count_objects_around do
      result = #{method_name_without_profiling}(*args)
    end
    payload[:call_depth] = ::ProfileTools.decrement_call_depth
    payload[:num_collection_calls] = collector.total_collection_calls - current_collection_calls
    result
  end
end
STR
    )

    kls.alias_method(method_name_without_profiling, method_name)
    kls.alias_method(method_name, method_name_with_profiling)
  end

  def generate_method_name(method_name, suffix)
    punctuation =
      if method_name =~ /(\?|!)$/
        $1
      else
        nil
      end

    method_name = method_name.sub(punctuation, '') if punctuation

    "#{method_name}_#{suffix}#{punctuation}"
  end
end
