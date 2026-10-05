# frozen_string_literal: true

module ProfileTools
  # Raised when asked to profile a method the class doesn't define
  class UnknownMethodError < Error; end
end
