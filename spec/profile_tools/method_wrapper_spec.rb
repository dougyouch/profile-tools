# frozen_string_literal: true

require 'spec_helper'

describe ProfileTools::MethodWrapper do
  def wrapper(name)
    described_class.new(ProfileTools::MethodName.new(name))
  end

  def wrap(*names)
    names.each { |name| wrapper(name).wrap }
  end

  def unwrap(*names)
    names.each { |name| wrapper(name).unwrap }
  end

  def run_twice(&)
    2.times { ProfileTools.instrument('block', &) }
    ProfileTools.profiler.collector
  end

  let(:model) { SimpleModel.new }

  after do
    unwrap(*@wrapped) if @wrapped
  end

  def wrap_for_example(*names)
    @wrapped = names
    wrap(*names)
  end

  describe '#wrap' do
    it 'measures the method' do
      wrap_for_example('SimpleModel#level1')

      collector = run_twice { model.level1 }

      expect(collector.stats['SimpleModel#level1'].allocations).to eq(1)
    end

    it 'adds no allocations to the caller' do
      # registered, so the collector creates their stats before measuring anything
      ProfileTools.profile('SimpleModel' => %w[level1 level2])

      collector = run_twice { model.level2(3) }

      expect(collector.stats['block'].allocations).to eq(4)
      expect(collector.stats['SimpleModel#level2'].allocations).to eq(4)
      expect(collector.stats['SimpleModel#level1'].allocations).to eq(1)
    end

    it 'measures class methods' do
      wrap_for_example('SimpleModel.level1!')

      collector = run_twice { SimpleModel.level1! }

      expect(collector.stats['SimpleModel.level1!'].allocations).to eq(2)
    end

    it 'passes keyword arguments and blocks through' do
      wrap_for_example('SimpleModel#with_keywords', 'SimpleModel#with_block')

      expect(model.with_keywords(2, scale: 3)).to eq(6)
      expect(model.with_block { |value| value * 5 }).to eq(10)
    end

    it 'wraps setters and operators' do
      wrap_for_example('SimpleModel#[]=')

      collector = run_twice { model[:key] = :value }

      expect(collector.stats['SimpleModel#[]='].calls).to eq(1)
    end

    it 'wraps methods whose names cannot be written with def' do
      wrap_for_example('SimpleModel#not-a-def-name')

      collector = run_twice { model.send(:'not-a-def-name') }

      expect(collector.stats['SimpleModel#not-a-def-name'].allocations).to eq(1)
    end

    it 'keeps private and protected methods hidden' do
      wrap_for_example('SimpleModel#secret', 'SimpleModel#guarded')

      expect { model.secret }.to raise_error(NoMethodError)
      expect { model.guarded }.to raise_error(NoMethodError)
      expect(model.call_secret).to eq(:secret)
      expect(model.call_guarded(SimpleModel.new)).to eq(:guarded)
    end

    it 'reuses one prepended module per class' do
      wrap_for_example('SimpleModel#level1', 'SimpleModel#level2')

      wrappers = SimpleModel.ancestors.grep(described_class::WrapperModule)
      expect(wrappers.size).to eq(1)
      expect(wrappers.first.inspect).to eq('ProfileTools::MethodWrapper::WrapperModule')
      expect(wrappers.first.to_s).to eq('ProfileTools::MethodWrapper::WrapperModule')
    end

    it 'raises for a method the class does not define' do
      expect { wrap('SimpleModel#missing') }.to raise_error(ProfileTools::UnknownMethodError, 'SimpleModel#missing is not defined')
    end
  end

  describe '#unwrap' do
    it 'stops measuring the method' do
      wrap('SimpleModel#level1')
      unwrap('SimpleModel#level1')

      collector = run_twice { model.level1 }

      expect(collector.stats['SimpleModel#level1']).to be_nil
      expect(model.level1).to be_an(Object)
    end
  end
end
