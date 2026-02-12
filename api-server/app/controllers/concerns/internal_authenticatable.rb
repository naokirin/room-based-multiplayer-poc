module InternalAuthenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_internal!
  end

  private

  def authenticate_internal!
    api_key = request.headers["X-Internal-Api-Key"]
    expected_key = ENV.fetch("INTERNAL_API_KEY") { raise "INTERNAL_API_KEY is required" }

    unless ActiveSupport::SecurityUtils.secure_compare(api_key.to_s, expected_key)
      render json: { error: "unauthorized" }, status: :unauthorized
    end
  end
end
