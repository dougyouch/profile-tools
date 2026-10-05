# frozen_string_literal: true

require 'spec_helper'

describe ProfileTools::Profiler do
  let(:profiler) { described_class.new }
  let(:events) { [] }
  let!(:subscription) do
    ActiveSupport::Notifications.subscribe(ProfileTools::EVENT) { |event| events << event }
  end

  after do
    ActiveSupport::Notifications.unsubscribe(subscription)
  end

  describe '#instrument' do
    it 'returns the block result' do
      expect(profiler.instrument { :result }).to eq(:result)
    end

    it 'publishes one event per run with the collector' do
      profiler.instrument('run') do
        profiler.instrument('nested') { nil }
      end

      expect(events.size).to eq(1)
      expect(events.first.payload[:name]).to eq('run')
      expect(events.first.payload[:collector]).to eq(profiler.collector)
      expect(profiler.collector.called_methods.map(&:method)).to eq(%w[run nested])
    end

    it 'uses the default name' do
      profiler.instrument { nil }

      expect(profiler.collector.called_methods.map(&:method)).to eq([described_class::DEFAULT_NAME])
    end

    it 'starts each run with a new collector holding the profiled methods' do
      ProfileTools.profile_method('SimpleModel#level1')
      profiler.instrument { nil }
      first = profiler.collector
      profiler.instrument { nil }

      expect(profiler.collector).not_to equal(first)
      expect(profiler.collector.stats.keys).to include('SimpleModel#level1')
    end

    it 'finishes the run when the block raises' do
      expect { profiler.instrument { raise ArgumentError } }.to raise_error(ArgumentError)

      expect(profiler).not_to be_running
      profiler.instrument { nil }
      expect(events.size).to eq(2)
    end

    it 'is running only inside a run' do
      expect(profiler).not_to be_running
      profiler.instrument { expect(profiler).to be_running }
    end
  end
end
