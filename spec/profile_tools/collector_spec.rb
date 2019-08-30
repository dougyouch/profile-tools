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
      collector.instrument(method_name) { code_block.call(code_block_iterations) }
      collector
    end
  end
  let(:collector_warmup) { execute_code_proc.call }
  let(:collector) { collector_warmup; execute_code_proc.call }
  let(:method_name) { 'block' }
  let(:code_block) { NEW_OBJECT_PROC }
  let(:code_block_iterations) { 1 }
  let(:method_stats) { collector.methods[method_name] }
  let(:count_objects) { method_stats[:count_objects] }

  context '#instrument' do
    describe 'single object' do
      subject { collector }

      it 'change object count' do
        subject
        expect(count_objects[:T_OBJECT]).to eq(code_block_iterations)
        expect(collector.total_objects_created).to eq(code_block_iterations)
      end
    end

    describe 'multiple objects' do
      let(:code_block_iterations) { 5 }

      it 'change object count' do
        subject
        expect(count_objects[:T_OBJECT]).to eq(code_block_iterations)
        expect(collector.total_objects_created).to eq(code_block_iterations)
      end
    end
  end
end
