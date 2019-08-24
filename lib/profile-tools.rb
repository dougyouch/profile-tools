# frozen_string_literal: true

class ProfileTools
  autoload :LogSubscriber, 'profile_tools/log_subscriber'

  def profile_instance_method(class_name, method_name)
    profile_method(Object.const_get(class_name), method_name)
  end

  def profile_class_method(class_name, method_name)
    profile_method(Object.const_get(class_name).singleton_class, method_name)
  end

  private

  def profile_method(kls, method_name)
    method_name_without_profiling = generate_method_name(method_name.to_s, 'without_profiling')
    method_name_with_profiling = generate_method_name(method_name.to_s, 'with_profiling')

    kls.class_eval(
<<-STR, __FILE__, __LINE__ + 1
def #{method_name_with_profiling}(*args)
  ActiveSupport::Notifications.instrument('method.profile_tools', method: '#{method_name}') do |payload|
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
end
