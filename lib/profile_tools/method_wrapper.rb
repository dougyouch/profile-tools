# frozen_string_literal: true

module ProfileTools
  # Adds and removes the profiling wrapper around a method.
  #
  # Wrappers live in a module prepended to the method's class (one per class, reused),
  # so the original method is never renamed. Each wrapper forwards its arguments with
  # `...` and calls `super`, which keeps positional, keyword and block arguments intact
  # and allocates nothing per call.
  class MethodWrapper
    # Method names that can't be written as `def name(...)`, wrapped with define_method instead.
    DEF_NAME = %r{\A(?:[A-Za-z_]\w*[?!=]?|\[\]=?|[-+]@|[-+*/%<>!~^&|`]|\*\*|<=>|===?|=~|!=|!~|<<|>>|<=|>=)\z}

    # Marks the modules this class prepends, so they're found again and shown clearly in ancestors.
    class WrapperModule < Module
      # @return [String]
      def inspect
        'ProfileTools::MethodWrapper::WrapperModule'
      end
      alias to_s inspect
    end

    # @param method_name [MethodName] the method to wrap
    def initialize(method_name)
      @method_name = method_name
      @owner = method_name.owner
    end

    # Wraps the method. Its visibility (public, protected or private) is kept.
    #
    # @return [void]
    # @raise [UnknownMethodError] if the class doesn't define the method
    def wrap
      visibility = method_visibility
      raise UnknownMethodError, "#{@method_name} is not defined" unless visibility

      define_wrapper(wrapper_module)
      wrapper_module.send(visibility, name)
    end

    # Removes the wrapper added by {#wrap}. The original method is untouched, so calls go
    # straight to it again.
    #
    # @return [void]
    def unwrap
      existing_wrapper_module.send(:remove_method, name)
    end

    private

    def name
      @method_name.method_name
    end

    def method_visibility
      if @owner.public_method_defined?(name) then :public
      elsif @owner.protected_method_defined?(name) then :protected
      elsif @owner.private_method_defined?(name) then :private
      end
    end

    def wrapper_module
      existing_wrapper_module || WrapperModule.new.tap { |module_| @owner.prepend(module_) }
    end

    # Only modules prepended directly to the owner come before it in its ancestors.
    def existing_wrapper_module
      @owner.ancestors.take_while { |ancestor| ancestor != @owner }.grep(WrapperModule).first
    end

    def define_wrapper(module_)
      if DEF_NAME.match?(name.to_s)
        module_.module_eval(def_source, __FILE__, __LINE__)
      else
        define_method_wrapper(module_)
      end
    end

    # `"...".freeze` compiles to a single frozen string, so passing the display name allocates nothing.
    def def_source
      <<~RUBY
        def #{name}(...)
          ::ProfileTools.profiler.instrument(#{@method_name.name.dump}.freeze) { super(...) }
        end
      RUBY
    end

    def define_method_wrapper(module_)
      display_name = @method_name.name
      module_.send(:define_method, name) do |*args, **kwargs, &block|
        ::ProfileTools.profiler.instrument(display_name) { super(*args, **kwargs, &block) }
      end
    end
  end
end
