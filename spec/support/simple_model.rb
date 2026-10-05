# frozen_string_literal: true

# Methods with known allocation counts for the specs
class SimpleModel
  def self.level1!
    new.level1
  end

  # allocates 1 object
  def level1
    Object.new
  end

  # allocates count objects plus whatever level1 allocates
  def level2(count = 1)
    count.times { Object.new }
    level1
  end

  def with_keywords(value, scale: 1)
    value * scale
  end

  def with_block
    yield 2
  end

  # allocates 1 object at the bottom of the recursion
  def countdown(number)
    number.zero? ? Object.new : countdown(number - 1)
  end

  def fail!
    raise ArgumentError, 'failed'
  end

  def []=(key, value)
    @values = { key => value }
  end

  define_method(:'not-a-def-name') { Object.new } # rubocop:disable Naming/MethodName

  def call_secret
    secret
  end

  def call_guarded(other)
    other.guarded
  end

  protected

  def guarded
    :guarded
  end

  private

  def secret
    :secret
  end
end
