# frozen_string_literal: true

ObjectSpace.count_objects

class ProfileTools
  autoload :LogSubscriber, 'profile_tools/log_subscriber'

  def profile_instance_method(class_name, method_name)
    profile_method(Object.const_get(class_name), class_name, method_name)
  end

  def profile_class_method(class_name, method_name)
    profile_method(Object.const_get(class_name).singleton_class, class_name, method_name)
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

  private

  def profile_method(kls, class_name, method_name)
    method_name_without_profiling = generate_method_name(method_name.to_s, 'without_profiling')
    method_name_with_profiling = generate_method_name(method_name.to_s, 'with_profiling')

    kls.class_eval(
<<-STR, __FILE__, __LINE__ + 1
def #{method_name_with_profiling}(*args)
  ActiveSupport::Notifications.instrument('method.profile_tools', class_name: '#{class_name}', method: '#{method_name}') do |payload|
    starting_objects = ObjectSpace.count_objects
    result = #{method_name_without_profiling}(*args)
    payload[:count_objects] = ::ProfileTools.count_objects_changes(starting_objects, ObjectSpace.count_objects)
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
