# frozen_string_literal: true

require 'spec_helper'

describe ProfileTools::Error do
  it 'is the base of the gem errors' do
    expect(described_class.superclass).to eq(StandardError)
    expect(ProfileTools::UnknownMethodError.superclass).to eq(described_class)
  end
end
