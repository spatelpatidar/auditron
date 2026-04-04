# frozen_string_literal: true

module Auditron
  class Railtie < Rails::Railtie
    # Store current request so auditable concern can read IP
    initializer "auditron.request_store" do |app|
      app.middleware.use(Auditron::RequestMiddleware)
    end
  end

  # Minimal Rack middleware — stores the current request thread-locally
  class RequestMiddleware
    def initialize(app)
      @app = app
    end

    def call(env)
      Auditron.current_request = ActionDispatch::Request.new(env)
      @app.call(env)
    ensure
      # Clear both after every request — prevents leaking between requests
      Auditron.current_actor   = nil
      Auditron.current_request = nil
    end
  end
end
