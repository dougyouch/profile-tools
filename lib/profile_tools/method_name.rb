# frozen_string_literal: true

module ProfileTools
  # A method to profile, named the way Ruby docs name methods:
  # "User#save" for an instance method, "User.find" for a class method.
  class MethodName
    # Splits "Class#method" or "Class.method". The class part may be namespaced ("Admin::User").
    PATTERN = /\A(?<class_name>[A-Z]\w*(?:::[A-Z]\w*)*)(?<separator>[#.])(?<method_name>.+)\z/

    # @return [String] the full name, such as "User#save"
    attr_reader :name

    # @return [String] the class or module name, such as "User"
    attr_reader :class_name

    # @return [Symbol] the method name, such as :save
    attr_reader :method_name

    # @param name [String, Symbol] "Class#method" or "Class.method"
    # @raise [Error] if the name isn't in either form
    def initialize(name)
      match = PATTERN.match(name.to_s)
      raise Error, "#{name.inspect} is not a method name, expected Class#method or Class.method" unless match

      @name = name.to_s.freeze
      @class_name = match[:class_name]
      @method_name = match[:method_name].to_sym
      @class_method = match[:separator] == '.'
    end

    # @return [Boolean] true for a class method ("User.find")
    def class_method?
      @class_method
    end

    # The class or module the method is defined on: the singleton class for a class method.
    # Looking it up loads the constant, so this autoloads app classes.
    #
    # @return [Module]
    # @raise [NameError] if the class doesn't exist
    def owner
      constant = Object.const_get(class_name)
      class_method? ? constant.singleton_class : constant
    end

    # @return [String] the full name
    def to_s
      name
    end
  end
end
