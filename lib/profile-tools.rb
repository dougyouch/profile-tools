# frozen_string_literal: true

require 'active_support/lazy_load_hooks'

# Profiles chosen methods without changing their code: call counts, time, objects allocated
# and garbage collection, per method and per request.
#
#   ProfileTools.profile('User' => ['save', '.find'])
#   ProfileTools.instrument('nightly import') { Importer.run }
#
# In a Rails app, list the methods in config/profile_tools.yml and restart; see {Railtie}.
module ProfileTools
  autoload :Collector, 'profile_tools/collector'
  autoload :Error, 'profile_tools/error'
  autoload :LogSubscriber, 'profile_tools/log_subscriber'
  autoload :MethodName, 'profile_tools/method_name'
  autoload :MethodStats, 'profile_tools/method_stats'
  autoload :MethodWrapper, 'profile_tools/method_wrapper'
  autoload :Middleware, 'profile_tools/middleware'
  autoload :Profiler, 'profile_tools/profiler'
  autoload :UnknownMethodError, 'profile_tools/unknown_method_error'
  autoload :VERSION, 'profile_tools/version'

  # ActiveSupport notification published when a profiling run finishes
  EVENT = 'profile.profile_tools'

  # Replaced, never changed in place, so a run that has already read it isn't affected.
  @profiled_methods = [].freeze

  class << self
    # @return [Array<String>] the profiled methods, such as ["User#save", "User.find"]
    attr_reader :profiled_methods

    # Profiles the methods listed in a YAML file: class names as keys, each with a list of
    # method names. Class methods start with a dot.
    #
    #   User:
    #     - save
    #     - .find
    #
    # @param path [String, Pathname]
    # @return [void]
    # @raise [Error] if the file isn't a mapping of class names to method names
    def load(path)
      require 'yaml'
      config = YAML.safe_load_file(path)
      raise Error, "#{path} must map class names to lists of methods" unless config.is_a?(Hash)

      profile(config)
    end

    # Profiles the methods in a hash shaped like the YAML file in {.load}.
    #
    # @param config [Hash{String => Array<String>, String}] class name => method names (".name" for class methods)
    # @return [void]
    def profile(config)
      config.each do |class_name, methods|
        Array(methods).each { |method| profile_method(full_method_name(class_name, method)) }
      end
    end

    # Starts profiling a method. Profiling one that already is does nothing.
    #
    # @param name [String] "Class#method" or "Class.method"
    # @return [void]
    # @raise [Error] if the name isn't in either form
    # @raise [NameError] if the class doesn't exist
    # @raise [UnknownMethodError] if the class doesn't define the method
    def profile_method(name)
      method_name = MethodName.new(name)
      return if profiled?(method_name.name)

      MethodWrapper.new(method_name).wrap
      @profiled_methods = [*@profiled_methods, method_name.name].freeze
    end

    # Stops profiling the given methods. Names that aren't profiled are ignored.
    #
    # @param names [Array<String>] "Class#method" or "Class.method"
    # @return [void]
    def stop_profiling(*names)
      names.map(&:to_s).select { |name| profiled?(name) }.each do |name|
        MethodWrapper.new(MethodName.new(name)).unwrap
        @profiled_methods = (@profiled_methods - [name]).freeze
      end
    end

    # Stops profiling every method.
    #
    # @return [void]
    def stop_profiling!
      stop_profiling(*profiled_methods)
    end

    # @param name [String] "Class#method" or "Class.method"
    # @return [Boolean] true if the method is being profiled
    def profiled?(name)
      profiled_methods.include?(name.to_s)
    end

    # @return [Profiler] the current thread's profiler
    def profiler
      Thread.current[:profile_tools_profiler] ||= Profiler.new
    end

    # Measures the block under the given name. Profiled methods it calls are reported with it.
    #
    # @param name [String] name to report the block under
    # @yield the code to measure
    # @return [Object] the block's result
    def instrument(name = Profiler::DEFAULT_NAME, &)
      profiler.instrument(name, &)
    end

    private

    def full_method_name(class_name, method)
      method = method.to_s
      method.start_with?('.') ? "#{class_name}#{method}" : "#{class_name}##{method}"
    end
  end
end

# Runs when a Rails app class is defined, early enough for the Railtie's initializers to run
ActiveSupport.on_load(:before_configuration) { require 'profile_tools/railtie' }
