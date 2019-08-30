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

    describe 'instrument level1' do
      before(:each) do
        ProfileTools.new.profile_instance_method(:SimpleModel, :level1)
        ProfileTools.new.profile_class_method(:SimpleModel, :level1!)
      end

      after(:each) do
        ProfileTools.stop_profiling!
      end

      it 'counts objects created' do
        subject
        expect(profiler.collector.methods['block'][:count_objects][:T_OBJECT]).to eq(1)
        expect(profiler.collector.methods['SimpleModel#level1'][:count_objects][:T_OBJECT]).to eq(1)
        expect(profiler.collector.methods['SimpleModel.level1!'][:count_objects][:T_OBJECT]).to eq(0)
      end

      describe 'instrument class method' do
        subject do
          2.times { profiler.instrument('block') { SimpleModel.level1! } }
        end

        it 'counts objects created' do
          subject
          expect(profiler.collector.methods['block'][:count_objects][:T_OBJECT]).to eq(2)
          expect(profiler.collector.methods['SimpleModel#level1'][:count_objects][:T_OBJECT]).to eq(1)
          expect(profiler.collector.methods['SimpleModel.level1!'][:count_objects][:T_OBJECT]).to eq(2)
        end
      end
    end
  end
end
