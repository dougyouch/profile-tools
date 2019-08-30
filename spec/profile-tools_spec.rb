require 'spec_helper'

describe ProfileTools do
  let(:profile_tools) { ProfileTools.new }

  after(:each) do
    ProfileTools.stop_profiling!
  end

  context 'profile_instance_method' do
    before(:each) do
      profile_tools.profile_instance_method(:SimpleModel, :level1)
    end

    describe '.profiled_methods' do
      subject { ProfileTools.profiled_methods }

      it 'profiled method is added' do
        expect(subject.include?('SimpleModel#level1')).to eq(true)
      end
    end

    describe 'remove_profiled_instance_method' do
      before(:each) do
        profile_tools.remove_profiled_instance_method(:SimpleModel, :level1)
      end

      describe '.profiled_methods' do
        subject { ProfileTools.profiled_methods }

        it 'profiled method is removed' do
          expect(subject.include?('SimpleModel#level1')).to eq(false)
        end
      end
    end
  end

  context 'profile_class_method' do
    before(:each) do
      profile_tools.profile_class_method(:SimpleModel, :level1!)
    end

    describe '.profiled_methods' do
      subject { ProfileTools.profiled_methods }

      it 'profiled method is added' do
        expect(subject.include?('SimpleModel.level1!')).to eq(true)
      end
    end

    describe 'remove_profiled_class_method' do
      before(:each) do
        profile_tools.remove_profiled_class_method(:SimpleModel, :level1!)
      end

      describe '.profiled_methods' do
        subject { ProfileTools.profiled_methods }

        it 'profiled method is removed' do
          expect(subject.include?('SimpleModel.level1!')).to eq(false)
        end
      end
    end
  end

  context '.load' do
    before(:each) do
      ProfileTools.load('spec/fixtures/profile.yml')
    end

    describe '.profiled_methods' do
      subject { ProfileTools.profiled_methods }

      it 'methods are profiled' do
        expect(subject.include?('SimpleModel#level1')).to eq(true)
        expect(subject.include?('SimpleModel.level1!')).to eq(true)
      end
    end
  end
end
