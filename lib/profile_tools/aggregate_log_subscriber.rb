# frozen_string_literal: true

class ProfileTools
  # collects nested 
  class AggregateLogSubscriber < ActiveSupport::LogSubscriber
    def method(event)
      event.payload[:collector].called_methods.each do |info|
        logger.info "method #{info[:method]} took #{info[:duration].round(5)}ms, called #{info[:calls]}, num_collection_calls: #{info[:num_collection_calls]}, objects: #{display_count_objects(info[:count_objects])}"
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
