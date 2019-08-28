# frozen_string_literal: true

class ProfileTools
  class LogSubscriber < ActiveSupport::LogSubscriber
    def method(event)
      logger.info "method #{event.payload[:display_name]} took #{event.duration.round(5)}ms, #{event.payload[:count_objects]}"
    end
  end
end
