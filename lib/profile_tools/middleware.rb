# frozen_string_literal: true

module ProfileTools
  # Rack middleware that makes each request one profiling run, so the profiled methods it calls
  # are reported together, under a "GET /path" line for the whole request.
  #
  # The {Railtie} adds it when a config file is present. Without it, every outermost call to a
  # profiled method is reported on its own.
  class Middleware
    # @param app [#call] the next Rack app
    def initialize(app)
      @app = app
    end

    # @param env [Hash] the Rack environment
    # @return [Array] the Rack response
    def call(env)
      ProfileTools.instrument("#{env['REQUEST_METHOD']} #{env['PATH_INFO']}") { @app.call(env) }
    end
  end
end
