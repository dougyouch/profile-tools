# frozen_string_literal: true

require 'spec_helper'

describe ProfileTools::Collector do
  let(:collector) { described_class.new(%w[outer inner]) }

  # the first run fills method caches, which allocates; measure the second.
  # The block gets the collector to nest calls in.
  def measure
    [described_class.new(%w[outer inner]), collector].each do |current|
      current.instrument('outer') { yield current }
    end
  end

  describe '#initialize' do
    it 'creates stats for the given methods' do
      expect(collector.stats.keys).to eq(%w[outer inner])
      expect(collector.called_methods).to eq([])
    end
  end

  describe '#instrument' do
    it 'returns the block result' do
      expect(collector.instrument('outer') { :result }).to eq(:result)
    end

    it 'counts objects allocated by the block exactly' do
      measure { 5.times { Object.new } }

      expect(collector.stats['outer'].allocations).to eq(5)
    end

    it 'includes nested calls in the outer total without adding overhead' do
      measure do |current|
        Object.new
        current.instrument('inner') { 2.times { Object.new } }
        current.instrument('inner') { Object.new }
      end

      expect(collector.stats['outer'].allocations).to eq(4)
      expect(collector.stats['inner'].allocations).to eq(3)
      expect(collector.stats['inner'].calls).to eq(2)
    end

    it 'stays exact when garbage collection runs mid-call' do
      measure do
        3.times { Object.new }
        GC.start
      end

      expect(collector.stats['outer'].allocations).to eq(3)
      expect(collector.stats['outer'].gc_count).to eq(1)
      expect(collector.stats['outer'].gc_time).to be >= 0
    end

    it 'times the block in milliseconds' do
      collector.instrument('outer') { sleep 0.01 }

      expect(collector.stats['outer'].duration).to be_between(9.0, 1000.0)
    end

    it 'counts recursive calls but measures only the outermost one' do
      measure do |current|
        current.instrument('outer') { Object.new }
      end

      expect(collector.stats['outer'].calls).to eq(2)
      expect(collector.stats['outer'].allocations).to eq(1)
    end

    it 'records calls that raise' do
      expect { collector.instrument('outer') { raise ArgumentError } }.to raise_error(ArgumentError)

      expect(collector.stats['outer'].calls).to eq(1)
      expect(collector.stats['outer']).not_to be_running
    end

    it 'adds stats for methods it was not given' do
      collector.instrument('other') { nil }

      expect(collector.stats['other'].calls).to eq(1)
    end
  end

  describe '#called_methods' do
    it 'returns the called methods in the order they were first called' do
      collector.instrument('other') do
        collector.instrument('inner') { nil }
        collector.instrument('other') { nil }
      end

      expect(collector.called_methods.map(&:method)).to eq(%w[other inner])
    end
  end
end
