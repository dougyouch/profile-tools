# frozen_string_literal: true

require 'spec_helper'

describe ProfileTools::MethodName do
  it 'parses an instance method' do
    name = described_class.new('SimpleModel#level1')

    expect(name.class_name).to eq('SimpleModel')
    expect(name.method_name).to eq(:level1)
    expect(name).not_to be_class_method
    expect(name.owner).to eq(SimpleModel)
    expect(name.to_s).to eq('SimpleModel#level1')
  end

  it 'parses a class method' do
    name = described_class.new(:'SimpleModel.level1!')

    expect(name.method_name).to eq(:level1!)
    expect(name).to be_class_method
    expect(name.owner).to eq(SimpleModel.singleton_class)
  end

  it 'parses namespaced classes and operator methods' do
    name = described_class.new('ProfileTools::Collector#[]=')

    expect(name.class_name).to eq('ProfileTools::Collector')
    expect(name.method_name).to eq(:[]=)
  end

  it 'freezes the name' do
    expect(described_class.new(+'SimpleModel#level1').name).to be_frozen
  end

  it 'rejects names in neither form' do
    expect { described_class.new('level1') }.to raise_error(ProfileTools::Error, /expected Class#method or Class.method/)
    expect { described_class.new('simple_model#level1') }.to raise_error(ProfileTools::Error)
  end

  it 'raises NameError for a class that does not exist' do
    expect { described_class.new('MissingModel#level1').owner }.to raise_error(NameError)
  end
end
