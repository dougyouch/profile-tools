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
          logger.info "method #{display_name} took #{info[:duration].round(5)}ms, called #{info[:calls]}, num_collection_calls: #{display_object_counts(info[:count_objects])}"
        end
      end
    end

    private

    def display_object_counts(object_counts)
      object_counts.reject! { |_, cnt| cnt == 0 }
      object_counts.delete(:FREE)
      object_counts.to_a { |k, v| "#{k}: #{v}" }.join(', ')
    end
  end
end
