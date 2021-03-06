require 'spec_helper'

describe ProfileTools::Collector do
  let(:collector_proc) do
    Proc.new do
      ProfileTools::Collector.new.tap do |c|
        c.init_method(method_name)
        10.times { |i| c.init_method("level#{i + 1}") }
      end
    end
  end
  let(:execute_code_proc) do
    Proc.new do
      collector = collector_proc.call
      collector.instrument(method_name) { code_block.call(collector, code_block_iterations) }
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
      it 'change object count' do
        expect(count_objects[:T_OBJECT]).to eq(code_block_iterations)
      end
    end

    describe 'multiple objects' do
      let(:code_block_iterations) { 5 }

      it 'change object count' do
        expect(count_objects[:T_OBJECT]).to eq(code_block_iterations)
      end
    end

    describe 'nested instrumentation' do
      let(:code_block) { NESTED_INSTRUMENT_OBJECT_PROC }

      it 'change object count' do
        expect(count_objects[:T_OBJECT]).to eq(19)
        expect(collector.methods['level1'][:count_objects][:T_OBJECT]).to eq(10)
        expect(collector.methods['level2'][:count_objects][:T_OBJECT]).to eq(6)
        expect(collector.methods['level3'][:count_objects][:T_OBJECT]).to eq(8)
        expect(collector.methods['level4'][:count_objects][:T_OBJECT]).to eq(8)
        expect(collector.methods['level5'][:count_objects][:T_OBJECT]).to eq(6)
      end
    end
  end

  context '#called_methods' do
    let(:code_block) { NESTED_INSTRUMENT_OBJECT_PROC }
    subject { collector.called_methods }

    it 'returns methods called in top down order' do
      expect(subject.map { |info| info[:method] }).to eq(['block', 'level1', 'level2', 'level3', 'level4', 'level5'])
    end
  end
end
