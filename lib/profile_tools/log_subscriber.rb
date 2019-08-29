# frozen_string_literal: true

class ProfileTools
  class LogSubscriber < ActiveSupport::LogSubscriber
    def profile(event)
      event.payload[:collector].called_methods.each do |info|
        logger.info "method #{info[:method]} took #{info[:duration].round(5)}ms, called #{info[:calls]}, objects: #{display_count_objects(info[:count_objects])}"
      end
    end

    private

    def display_count_objects(count_objects)
      count_objects.reject! { |_, cnt| cnt == 0 }
      count_objects.delete(:FREE)
      count_objects.to_a.map { |k, v| "#{k}: #{v}" }.join(', ')
    end
  end
end
