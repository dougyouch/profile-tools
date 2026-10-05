# frozen_string_literal: true

require 'spec_helper'

describe ProfileTools do
  let(:model) { SimpleModel.new }

  describe '.profile_method' do
    it 'profiles the method' do
      described_class.profile_method('SimpleModel#level1')

      expect(described_class.profiled_methods).to eq(['SimpleModel#level1'])
      expect(described_class).to be_profiled('SimpleModel#level1')
      expect(described_class.profiled_methods).to be_frozen
    end

    it 'ignores a method that is already profiled' do
      2.times { described_class.profile_method('SimpleModel#level1') }
      described_class.instrument { model.level1 }

      expect(described_class.profiled_methods).to eq(['SimpleModel#level1'])
      expect(described_class.profiler.collector.stats['SimpleModel#level1'].calls).to eq(1)
    end

    it 'raises for a method the class does not define' do
      expect { described_class.profile_method('SimpleModel#missing') }.to raise_error(ProfileTools::UnknownMethodError)
      expect(described_class.profiled_methods).to eq([])
    end
  end

  describe '.profile' do
    it 'profiles instance and class methods by class' do
      described_class.profile('SimpleModel' => %w[level1 .level1!])

      expect(described_class.profiled_methods).to eq(['SimpleModel#level1', 'SimpleModel.level1!'])
    end

    it 'accepts a single method name' do
      described_class.profile(SimpleModel: :level2)

      expect(described_class.profiled_methods).to eq(['SimpleModel#level2'])
    end
  end

  describe '.load' do
    it 'profiles the methods listed in a YAML file' do
      described_class.load('spec/fixtures/profile.yml')

      expect(described_class.profiled_methods).to eq(['SimpleModel#level1', 'SimpleModel.level1!'])
    end

    it 'accepts a single method per class' do
      described_class.load(Pathname.new('spec/fixtures/single_method.yml'))

      expect(described_class.profiled_methods).to eq(['SimpleModel#level2'])
    end

    it 'rejects a file that is not a mapping' do
      expect { described_class.load('spec/fixtures/not_a_mapping.yml') }
        .to raise_error(ProfileTools::Error, 'spec/fixtures/not_a_mapping.yml must map class names to lists of methods')
    end
  end

  describe '.stop_profiling' do
    before do
      described_class.profile('SimpleModel' => %w[level1 level2])
    end

    it 'stops profiling the given methods and ignores the rest' do
      described_class.stop_profiling('SimpleModel#level1', :'SimpleModel#level2', 'SimpleModel#with_block')
      described_class.instrument { model.level2 }

      expect(described_class.profiled_methods).to eq([])
      expect(described_class.profiler.collector.called_methods.map(&:method)).to eq([ProfileTools::Profiler::DEFAULT_NAME])
    end
  end

  describe '.stop_profiling!' do
    it 'stops profiling every method' do
      described_class.profile('SimpleModel' => %w[level1 .level1!])
      described_class.stop_profiling!

      expect(described_class.profiled_methods).to eq([])
      expect(described_class).not_to be_profiled('SimpleModel#level1')
    end
  end

  describe '.profiler' do
    it 'is kept per thread' do
      other = Thread.new { described_class.profiler }.value

      expect(described_class.profiler).to equal(described_class.profiler)
      expect(described_class.profiler).not_to equal(other)
    end
  end

  describe '.instrument' do
    it 'measures the block and the profiled methods it calls' do
      described_class.profile_method('SimpleModel.level1!')

      result = 2.times.map { described_class.instrument('job') { SimpleModel.level1! } }.last

      expect(result).to be_an(Object)
      expect(described_class.profiler.collector.stats['job'].allocations).to eq(2)
      expect(described_class.profiler.collector.stats['SimpleModel.level1!'].allocations).to eq(2)
    end
  end

  it 'has a version' do
    expect(ProfileTools::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end
end
