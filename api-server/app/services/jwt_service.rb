class JwtService
  ALGORITHM = "HS256"
  DEFAULT_EXPIRATION = 1.hour

  class << self
    def encode(payload, expiration: DEFAULT_EXPIRATION)
      payload = payload.dup
      payload[:exp] = expiration.from_now.to_i
      payload[:iat] = Time.current.to_i
      JWT.encode(payload, secret_key, ALGORITHM)
    end

    def decode(token)
      decoded = JWT.decode(token, secret_key, true, algorithm: ALGORITHM)
      HashWithIndifferentAccess.new(decoded.first)
    rescue JWT::DecodeError, JWT::ExpiredSignature, JWT::VerificationError => e
      nil
    end

    private

    def secret_key
      ENV.fetch("JWT_SECRET") { raise "JWT_SECRET environment variable is required" }
    end
  end
end
