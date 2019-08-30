require 'spec_helper'

describe ProfileTools::Collector do
  let(:collector_proc) do
    Proc.new do
      ProfileTools::Collector.new.tap do |c|
        c.init_method(method_name)
      end
    end
  end
  let(:execute_code_proc) do
    Proc.new do
      collector = collector_proc.call
      collector.instrument(method_name) { code_block.call }
      collector
    end
  end
  let(:collector_warmup) { execute_code_proc.call }
  let(:collector) { collector_warmup; execute_code_proc.call }
  let(:method_name) { 'block' }
  let(:code_block) { NEW_OBJECT_PROC }
  let(:method_stats) { collector.methods[method_name] }
  let(:count_objects) { method_stats[:count_objects] }

  context '#instrument' do
    describe 'single object' do
      subject { collector }

      it 'change object count' do
        subject
        expect(count_objects[:T_OBJECT]).to eq(1)
        expect(collector.total_objects_created).to eq(1)
      end
    end
  end
end
