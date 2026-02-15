# frozen_string_literal: true

# CORS: allow API requests from the client app (different origin).
# OPTIONS preflight requests are handled by this middleware; no route needed.
# Configure allowed origins via CORS_ALLOWED_ORIGINS (comma-separated) or leave blank for dev defaults.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins_env = ENV.fetch("CORS_ALLOWED_ORIGINS", nil)
    origins_list = if origins_env.present?
                     origins_env.split(",").map(&:strip).reject(&:empty?)
    else
                     # Dev defaults when not set (Vite, etc.)
                     %w[
                       http://localhost:5173
                       http://localhost:3000
                       http://127.0.0.1:5173
                       http://127.0.0.1:3000
                     ]
    end

    origins(*origins_list)
    resource "/api/*",
             headers: :any,
             methods: %i[get post put patch delete options head],
             expose: %w[Authorization],
             credentials: true
  end
end
