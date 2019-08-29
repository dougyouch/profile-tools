require 'spec_helper'

describe ProfileTools::Collector do
  let(:collector) do
    ProfileTools::Collector.new.tap do |c|
      c.init_method(method_name)
    end
  end
  let(:method_name) { 'block' }
  let(:code_block) { NEW_OBJECT_PROC }
  let(:method_stats) { collector.methods[method_name] }
  let(:count_objects) { method_stats[:count_objects] }

  context '#instrument' do
    describe 'single object' do
      subject { collector.instrument(method_name) { code_block.call } }

      it 'change object count' do
        subject
        expect(count_objects[:T_OBJECT]).to eq(1)
      end
    end
  end
end
