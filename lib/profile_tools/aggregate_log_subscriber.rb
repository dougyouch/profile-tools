# frozen_string_literal: true

class ProfileTools
  # collects nested 
  class AggregateLogSubscriber < ActiveSupport::LogSubscriber
    def method(event)
      event.payload[:collector].add(
        event.payload[:display_name],
        event.duration,
        event.payload[:count_objects]
      )

      if event.payload[:call_depth] == 0
        ::ProfileTools.reset_collector
        event.payload[:collector].methods.each do |display_name, info|
          logger.info "method #{display_name} took #{info[:duration].round(5)}ms, called #{info[:calls]}, #{info[:count_objects]}"
        end
      end
    end
  end
end
