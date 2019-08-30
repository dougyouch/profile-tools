require 'spec_helper'

describe ProfileTools::Profiler do
  let(:profiler) { ProfileTools.profiler }
  let(:model) { SimpleModel.new }

  context '#instrument' do
    subject do
      2.times { profiler.instrument('block') { model.level1 } }
    end

    it 'counts objects created' do
      subject
      expect(profiler.collector.methods['block'][:count_objects][:T_OBJECT]).to eq(1)
    end
  end
end
