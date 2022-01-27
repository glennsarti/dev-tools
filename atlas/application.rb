require_relative 'boot'

# Pick the frameworks you want:
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "sprockets/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Atlas
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    config.active_record.schema_format = :sql

    # In Rails 6.1, request.content_type will return the content-type header
    # without modification
    # In <=6.0 the charset was stripped from the content-type (essentially leaving
    # just the mime-type)
    # This doesn't play nicely with active model serializer as it is built against
    # the original behavior
    # This config option turns off the new behavior and removes deprecations for 6.1
    # https://github.com/rails/rails/commit/ddb6d788d6a611fd1ba6cf92ad6d1342079517a8
    config.action_dispatch.return_only_media_type_on_content_type = false

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de
    config.i18n.enforce_available_locales = true

    # Block requests by IP address.
    config.middleware.use Rack::Attack

    # Add rate limiting headers when a request is NOT rate limited.
    require_relative "../app/middleware/attach_rate_limit_headers"
    config.middleware.use ::AttachRateLimitHeaders

    # Sanitize UTF8 chars in requests
    config.middleware.insert 0, Rack::UTF8Sanitizer

    # Some Rack middleware to actually catch JSON input errors.
    require_relative "../app/middleware/catch_json_parse_errors"
    config.middleware.use(CatchJsonParseErrors)

    # Disable checks for IP spoofing. Because we are behind and ELB and make
    # heavy use of X-Forwarded-For. There are bugs/features in Rails that cause
    # this to raise exceptions, so we disable it here.
    config.action_dispatch.ip_spoofing_check = false

    # Add everything in lib to autolaod
    config.autoload_paths   << Rails.root.join("lib")
    config.eager_load_paths << Rails.root.join("lib")
    config.autoload_paths   << Rails.root.join("app/serializers/concerns")
    config.eager_load_paths << Rails.root.join("app/serializers/concerns")
    config.autoload_paths   << Rails.root.join("app/interactors/concerns")
    config.eager_load_paths << Rails.root.join("app/interactors/concerns")

    # When running a dockerized development setup, load a different development.yml for settings.
    if Rails.env == "development" && ENV["DOCKER_DEV"]
      Settings.reload_from_files(
        Rails.root.join("config", "settings.yml").to_s,
        Rails.root.join("docker", "terraform-enterprise", "#{Rails.env}.yml").to_s,
        Rails.root.join("docker", "terraform-enterprise", "#{Rails.env}.local.yml").to_s
      )
    end

    config.log_level = Settings.rails_log_level

    require Rails.root.join("lib/custom_public_exceptions")
    config.exceptions_app = CustomPublicExceptions.new(Rails.public_path)


    routes.default_url_options = {
      host: Settings.basic.base_domain,
      protocol: Settings.basic.protocol
    }

    # Load settings from config/redis.yml
    config.redis = config_for(:redis).symbolize_keys

    # CORS config
    config.middleware.insert_before 0, Rack::Cors, :debug => false, :logger => (-> { Rails.logger }) do
      allow do
        origins "#{Settings.basic.pretty_url}"
        resource "*", headers: :any, methods: [:get, :post, :options]
      end
    end


    require_relative "../lib/formatters/atlas_logger"
    # Logging

    # Use our custom log format
    config.log_formatter = Formatters::AtlasLogger.new

    # https://github.com/rails/rails/pull/34591
    config.action_mailer.delivery_job = "ActionMailer::MailDeliveryJob"

    # Rails 6 offers a feature to guard against DNS rebinding attacks by blocking requests from domains
    # not in the allowlist. This causes unexpected complications if say, internal services call to
    # Atlas using a domain that's different from the public domain (like in our Dockerized tfe:local
    # setup). We can disable it for now by setting the `hosts` allowlist to empty.
    # More info: https://guides.rubyonrails.org/configuring.html#configuring-middleware
    Rails.application.config.hosts.clear

    require_relative "../lib/formatters/request"
    # Compact logs
    config.lograge.enabled = true
    config.lograge.formatter = Formatters::Request.new
    config.lograge.custom_options = lambda do |event|
      h = {}

      h[:time] = event.time
      h[:uuid] = event.payload[:uuid]
      h[:remote_ip] = event.payload[:remote_ip]
      h[:request_id] = event.payload[:request_id]
      h[:user_agent] = event.payload[:user_agent]

      [:user, :organization].each do |field|
        h[field] = event.payload[field] if event.payload[field]
      end

      # Source:
      # https://docs.datadoghq.com/tracing/connect_logs_and_traces/ruby/#manual-injection
      # Retrieves trace information for current thread
      if Datadog.respond_to?(:tracer)
        correlation = Datadog.tracer.active_correlation
        # Adds IDs as tags to log output
        h[:dd] = {
          # To preserve precision during JSON serialization, use strings for large numbers
          :trace_id => correlation&.trace_id.to_s,
          :span_id => correlation&.span_id.to_s,
          :env => correlation&.env.to_s,
          :service => correlation&.service.to_s,
          :version => correlation&.version.to_s
        }
      end
      h[:ddsource] = ["ruby"]
      h[:params] = event.payload[:params].reject { |k| %w(controller action).include? k }

      h
    end

    config.lograge.custom_payload do |controller|
      {
        remote_ip: controller.request.headers["X-Forwarded-For"] || controller.request.remote_ip,
        request_id: controller.request.uuid,
        user: controller.send(:current_user).try(:username),
        user_agent: controller.request.user_agent,
        uuid: controller.request.uuid,
        auth_source: controller.try(:auth_client)
      }
    end

  end
end
