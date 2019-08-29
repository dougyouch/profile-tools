# frozen_string_literal: true

class ProfileTools
  autoload :Collector, 'profile_tools/collector'
  autoload :LogSubscriber, 'profile_tools/log_subscriber'

  EVENT = 'profile.profile_tools'
  
  @@profiled_methods = []
  def self.profiled_methods
    @@profiled_methods
  end

  def self.add_method(display_name)
    profiled_methods << display_name
  end

  def initialize
    ObjectSpace.count_objects
  end

  def profile_instance_method(class_name, method_name)
    profile_method(Object.const_get(class_name), method_name, "#{class_name}##{method_name}")
  end

  def profile_class_method(class_name, method_name)
    profile_method(Object.const_get(class_name).singleton_class, method_name, "#{class_name}.#{method_name}")
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

  def self.instrument(display_name = 'ProfileTools.instrument')
    result = nil
    if increment_call_depth == 1
      reset_collector
      collector.init_method(display_name)
      ActiveSupport::Notifications.instrument(EVENT, collector: collector) do |payload|
        collector.instrument(display_name) do
          result = yield
        end
      end
    else
      collector.instrument(display_name) do
        result = yield
      end
    end
    decrement_call_depth
    result
  end

  def self.count_objects_changes(starting_objects, new_objects)
    new_objects.each do |name, cnt|
      new_objects[name] -= starting_objects[name]
      new_objects[name] -= 1 if name == :T_HASH
    end
  end

  def self.count_objects_around
    starting_objects = ObjectSpace.count_objects
    yield
    ::ProfileTools.count_objects_changes(starting_objects, ObjectSpace.count_objects)
  end

  def self.increment_call_depth
    Thread.current[:profile_tools_call_depth] ||= 0
    Thread.current[:profile_tools_call_depth] += 1
  end

  def self.decrement_call_depth
    Thread.current[:profile_tools_call_depth] -= 1
  end

  def self.collector
    Thread.current[:profile_tools_collector] ||= Collector.new.tap do |collector|
      profiled_methods.each { |display_name| collector.init_method(display_name) }
    end
  end

  def self.reset_collector
    Thread.current[:profile_tools_collector] = nil
  end

  private

  def profile_method(kls, method_name, display_name)
    self.class.add_method(display_name)

    method_name_without_profiling = generate_method_name(method_name.to_s, 'without_profiling')
    method_name_with_profiling = generate_method_name(method_name.to_s, 'with_profiling')

    kls.class_eval(
<<-STR, __FILE__, __LINE__ + 1
def #{method_name_with_profiling}(*args)
  ::ProfileTools.instrument('#{display_name}') do
    #{method_name_without_profiling}(*args)
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

  def now
    Concurrent.monotonic_time
  end
end
