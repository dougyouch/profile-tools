# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'rails'
require 'action_controller/railtie'

# A string, not the constant: the Railtie is only defined once a Rails app class is created
describe 'ProfileTools::Railtie' do
  let(:railtie) { ProfileTools::Railtie }

  # Boots one app per process, with the config file in place
  before(:all) do
    @log = StringIO.new
    @root = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@root, 'config'))
    FileUtils.cp('spec/fixtures/profile.yml', File.join(@root, 'config/profile_tools.yml'))

    root = @root
    log = @log
    @app = Class.new(Rails::Application) do
      config.root = root
      config.eager_load = false
      config.logger = Logger.new(log)
      config.secret_key_base = 'profile-tools'
      config.hosts.clear
    end
    @app.initialize!
    @app.routes.draw do
      get '/models', to: ->(_env) { [200, {}, [SimpleModel.level1!.class.name]] }
    end
  end

  after(:all) do
    ProfileTools.stop_profiling!
    ProfileTools::LogSubscriber.detach_from :profile_tools
    FileUtils.rm_rf(@root)
  end

  # the shared after hook stops profiling after each example; profile again from the file
  before do
    railtie.profile(@app)
  end

  it 'is defined when the Rails app class is created' do
    expect(Rails::Railtie.subclasses).to include(ProfileTools::Railtie)
  end

  it 'profiles the methods in config/profile_tools.yml' do
    expect(ProfileTools.profiled_methods).to eq(['SimpleModel#level1', 'SimpleModel.level1!'])
  end

  it 'adds the middleware after the Rails logger' do
    middleware = @app.middleware.map(&:klass)

    expect(middleware.index(ProfileTools::Middleware)).to eq(middleware.index(Rails::Rack::Logger) + 1)
  end

  it 'logs the profiled methods for each request' do
    status, = @app.call(Rack::MockRequest.env_for('/models'))

    expect(status).to eq(200)
    expect(@log.string).to include('[ProfileTools] GET /models: 1 call')
    expect(@log.string).to include('[ProfileTools] SimpleModel.level1!: 1 call')
    expect(@log.string).to include('[ProfileTools] SimpleModel#level1: 1 call')
  end

  describe '.config_path' do
    let(:app) { double(root: Pathname.new('/app')) }

    it 'defaults to config/profile_tools.yml' do
      expect(railtie.config_path(app)).to eq(Pathname.new('/app/config/profile_tools.yml'))
    end

    it 'can be set with PROFILE_TOOLS_CONFIG' do
      ENV['PROFILE_TOOLS_CONFIG'] = '/tmp/profile.yml'

      expect(railtie.config_path(app)).to eq(Pathname.new('/tmp/profile.yml'))
    ensure
      ENV.delete('PROFILE_TOOLS_CONFIG')
    end
  end

  context 'without a config file' do
    let(:app) { double(root: Pathname.new(Dir.tmpdir).join('profile-tools-missing')) }

    it 'adds nothing' do
      ProfileTools.stop_profiling!

      railtie.setup(app)
      railtie.profile(app)

      expect(ProfileTools.profiled_methods).to eq([])
    end
  end
end
