# frozen_string_literal: true

require 'spec_helper'

describe ProfileTools::Middleware do
  let(:app) { ->(_env) { SimpleModel.new.level1 && [200, {}, ['ok']] } }
  let(:middleware) { described_class.new(app) }

  it 'runs each request as one profiling run named after it' do
    ProfileTools.profile_method('SimpleModel#level1')

    response = middleware.call('REQUEST_METHOD' => 'GET', 'PATH_INFO' => '/users')

    expect(response).to eq([200, {}, ['ok']])
    expect(ProfileTools.profiler.collector.called_methods.map(&:method)).to eq(['GET /users', 'SimpleModel#level1'])
  end
end
