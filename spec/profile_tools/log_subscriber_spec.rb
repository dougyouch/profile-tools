# frozen_string_literal: true

require 'spec_helper'

describe ProfileTools::LogSubscriber do
  let(:io) { StringIO.new }
  let(:subscriber) { described_class.new }

  before do
    @logger = ActiveSupport::LogSubscriber.logger
    ActiveSupport::LogSubscriber.logger = Logger.new(io)
  end

  after do
    ActiveSupport::LogSubscriber.logger = @logger
  end

  def event_for(collector)
    ActiveSupport::Notifications::Event.new(ProfileTools::EVENT, nil, nil, 'id', collector: collector)
  end

  def stats(method, calls:, allocations:, gc_count:)
    ProfileTools::MethodStats.new(method).tap do |stats|
      calls.times { stats.enter(1) }
      stats.add(1.23456, allocations, gc_count, gc_count * 2)
    end
  end

  it 'logs a line per called method' do
    collector = instance_double(
      ProfileTools::Collector,
      called_methods: [
        stats('run', calls: 1, allocations: 1, gc_count: 1),
        stats('SimpleModel#level1', calls: 2, allocations: 0, gc_count: 0)
      ]
    )

    subscriber.profile(event_for(collector))

    lines = io.string.lines
    expect(lines.size).to eq(2)
    expect(lines[0]).to end_with("[ProfileTools] run: 1 call, 1.235ms, 1 allocation, 1 GC run (2ms)\n")
    expect(lines[1]).to end_with("[ProfileTools] SimpleModel#level1: 2 calls, 1.235ms, 0 allocations, 0 GC runs (0ms)\n")
  end

  it 'logs runs published by the profiler once attached' do
    described_class.attach_to :profile_tools

    ProfileTools.instrument('attached run') { nil }

    expect(io.string).to include('[ProfileTools] attached run: 1 call')
  ensure
    described_class.detach_from :profile_tools
  end
end
