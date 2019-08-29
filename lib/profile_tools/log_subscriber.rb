# frozen_string_literal: true

class ProfileTools
  # Logs the collector stats
  class LogSubscriber < ActiveSupport::LogSubscriber
    def profile(event)
      event.payload[:collector].called_methods.each do |info|
        duration = info[:duration].round(5)
        count_objects = display_count_objects(info[:count_objects])
        logger.info "method #{info[:method]} took #{duration}ms, called #{info[:calls]}, objects: #{count_objects}"
      end
    end

    private

    def display_count_objects(count_objects)
      count_objects.reject! { |_, cnt| cnt.zero? }
      count_objects.delete(:FREE)
      count_objects.to_a.map { |k, v| "#{k}: #{v}" }.join(', ')
    end
  end
end
