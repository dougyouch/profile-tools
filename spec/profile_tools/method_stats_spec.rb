# frozen_string_literal: true

require 'spec_helper'

describe ProfileTools::MethodStats do
  subject(:stats) { described_class.new('SimpleModel#level1') }

  it 'starts with nothing recorded' do
    expect(stats.to_h).to eq(
      method: 'SimpleModel#level1', calls: 0, duration: 0.0, allocations: 0, gc_count: 0, gc_time: 0
    )
    expect(stats).not_to be_called
    expect(stats).not_to be_running
    expect(stats.sort_order).to be_nil
  end

  describe '#enter and #leave' do
    it 'counts calls, tracks nesting and keeps the first sort order' do
      stats.enter(3)
      expect(stats).to be_running
      stats.enter(5)
      stats.leave
      expect(stats).to be_running
      stats.leave

      expect(stats).not_to be_running
      expect(stats).to be_called
      expect(stats.calls).to eq(2)
      expect(stats.sort_order).to eq(3)
    end
  end

  describe '#add' do
    it 'adds to the totals' do
      stats.add(1.5, 10, 1, 2)
      stats.add(0.5, 5, 0, 0)

      expect(stats.to_h).to include(duration: 2.0, allocations: 15, gc_count: 1, gc_time: 2)
    end
  end
end
