# frozen_string_literal: true

require 'rails/railtie'

module ProfileTools
  # Turns profiling on in a Rails app when a config file is present, with no code changes:
  # put the file in place, restart, read the log, remove the file, restart.
  #
  # The file is config/profile_tools.yml, or the path in the PROFILE_TOOLS_CONFIG environment
  # variable. When it exists, the Railtie adds {Middleware} after Rails::Rack::Logger (so log
  # lines keep the request's tags), attaches {LogSubscriber}, and once the app has booted
  # (and eager loaded) wraps the methods the file lists.
  class Railtie < Rails::Railtie
    initializer('profile_tools.middleware') { |app| ProfileTools::Railtie.setup(app) }
    config.after_initialize { |app| ProfileTools::Railtie.profile(app) }

    class << self
      # @param app [Rails::Application]
      # @return [Pathname] where the config file is looked for
      def config_path(app)
        Pathname.new(ENV.fetch('PROFILE_TOOLS_CONFIG') { app.root.join('config/profile_tools.yml') })
      end

      # Adds the middleware and log subscriber if the config file exists.
      #
      # @api private
      # @param app [Rails::Application]
      # @return [void]
      def setup(app)
        return unless config_path(app).exist?

        app.config.middleware.insert_after Rails::Rack::Logger, ProfileTools::Middleware
        ProfileTools::LogSubscriber.attach_to :profile_tools
      end

      # Profiles the methods in the config file if it exists.
      #
      # @api private
      # @param app [Rails::Application]
      # @return [void]
      def profile(app)
        path = config_path(app)
        ProfileTools.load(path) if path.exist?
      end
    end
  end
end
