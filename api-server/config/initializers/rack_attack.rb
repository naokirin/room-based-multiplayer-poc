class Rack::Attack
  # Disable rate limiting in test environment
  Rack::Attack.enabled = false if Rails.env.test?

  # Use Redis for rate limiting
  unless Rails.env.test?
    Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
      url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0")
    )
  end

  # Auth endpoints - per IP
  throttle("auth/register", limit: 5, period: 60) do |req|
    req.ip if req.path == "/api/v1/auth/register" && req.post?
  end

  throttle("auth/login", limit: 10, period: 60) do |req|
    req.ip if req.path == "/api/v1/auth/login" && req.post?
  end

  # Matchmaking - per user (by JWT)
  throttle("matchmaking/join", limit: 3, period: 60) do |req|
    if req.path == "/api/v1/matchmaking/join" && req.post?
      token = req.env["HTTP_AUTHORIZATION"]&.split(" ")&.last
      payload = JwtService.decode(token) if token
      payload&.dig(:user_id)
    end
  end

  throttle("matchmaking/status", limit: 20, period: 60) do |req|
    if req.path == "/api/v1/matchmaking/status" && req.get?
      token = req.env["HTTP_AUTHORIZATION"]&.split(" ")&.last
      payload = JwtService.decode(token) if token
      payload&.dig(:user_id)
    end
  end

  # Custom response for throttled requests
  self.throttled_responder = lambda do |req|
    retry_after = (req.env["rack.attack.match_data"] || {})[:period]
    [
      429,
      { "Content-Type" => "application/json", "Retry-After" => retry_after.to_s },
      [ { error: "rate_limited", message: "Too many requests, please try again later", retry_after: retry_after }.to_json ]
    ]
  end
end
