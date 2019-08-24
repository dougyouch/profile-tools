# frozen_string_literal: true

class ProfileTools
  class LogSubscriber < ActiveSupport::LogSubscriber
    def method(event)
      logger.info "method #{event.payload[:class_name]}.#{event.payload[:method]} took #{event.duration}ms, #{event.payload[:count_objects]}"
    end
  end
end
