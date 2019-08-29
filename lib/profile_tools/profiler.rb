# frozen_string_literal: true

class ProfileTools
  # Aggregates profile stats into the collector
  class Profiler
    def initialize(collector)
      @collector = collector
    end

    def instrument(class_and_method_name = 'ProfileTools::Profiler#instrument')
      result = nil
      if increment_call_depth == 1
        instrument_with_notifications(class_and_method_name) do
          result = yield
        end
      else
        instrument_with_collector(class_and_method_name) do
          result = yield
        end
      end
      decrement_call_depth
      result
    end

    private

    def instrument_with_notifications(class_and_method_name)
      ActiveSupport::Notifications.instrument(EVENT, collector: @collector) do
        instrument_with_collector(class_and_method_name) do
          yield
        end
      end
    end

    def instrument_with_collector(class_and_method_name)
      @collector.instrument(class_and_method_name) do
        yield
      end
    end
  end
end
