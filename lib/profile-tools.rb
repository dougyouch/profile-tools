# frozen_string_literal: true

# ProfileTools is used to instrument specific methods.  Provides feedback about method execution
#  time and number of objects created.
class ProfileTools
  autoload :Collector, 'profile_tools/collector'
  autoload :LogSubscriber, 'profile_tools/log_subscriber'
  autoload :Profiler, 'profile_tools/profiler'

  EVENT = 'profile.profile_tools'

  @profiled_methods = []
  class << self
    attr_reader :profiled_methods
  end

  def self.add_method(display_name)
    profiled_methods << display_name
  end

  def self.delete_method(display_name)
    profiled_methods.delete_if { |method| method == display_name }
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

  def remove_profiled_instance_method(class_name, method_name)
    remove_profiling(Object.const_get(class_name), method_name, "#{class_name}##{method_name}")
  end

  def remove_profiled_class_method(class_name, method_name)
    remove_profiling(Object.const_get(class_name).singleton_class, method_name, "#{class_name}.#{method_name}")
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

  def self.stop_profiling(methods)
    profile_tools = new

    methods.each do |method|
      if method =~ /#/
        profile_tools.remove_profiled_instance_method(*method.split('#', 2))
      elsif method =~ /\./
        profile_tools.remove_profiled_class_method(*method.split('.', 2))
      end
    end
  end

  def self.stop_profiling!
    stop_profiling(profiled_methods.dup)
  end

  def self.profiler
    Thread.current[:profile_tools_profiler] ||= Profiler.new
  end

  def self.instrument
    profiler.instrument do
      yield
    end
  end

  private

  def profile_method(kls, method_name, display_name)
    self.class.add_method(display_name)

    method_name_without_profiling = generate_method_name(method_name.to_s, 'without_profiling')
    method_name_with_profiling = generate_method_name(method_name.to_s, 'with_profiling')

    kls.class_eval(
<<-STR, __FILE__, __LINE__ + 1
def #{method_name_with_profiling}(*args)
  ::ProfileTools.profiler.instrument('#{display_name}') do
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
      end

    method_name = method_name.sub(punctuation, '') if punctuation

    "#{method_name}_#{suffix}#{punctuation}"
  end

  def remove_profiling(kls, method_name, display_name)
    self.class.delete_method(display_name)

    method_name_without_profiling = generate_method_name(method_name.to_s, 'without_profiling')
    method_name_with_profiling = generate_method_name(method_name.to_s, 'with_profiling')

    kls.alias_method(method_name, method_name_without_profiling)
    kls.send(:remove_method, method_name_with_profiling)
    kls.send(:remove_method, method_name_without_profiling)
  end
end
