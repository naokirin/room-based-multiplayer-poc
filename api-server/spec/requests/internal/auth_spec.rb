require "rails_helper"

RSpec.describe "Internal::Auth", type: :request do
  let(:api_key) { "test-internal-api-key" }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("INTERNAL_API_KEY").and_return(api_key)
  end

  describe "POST /internal/auth/verify" do
    let(:user) { create(:user) }

    it "returns valid response for valid token" do
      token = JwtService.encode({ user_id: user.id })

      post "/internal/auth/verify",
           params: { token: token },
           headers: { "X-Internal-Api-Key" => api_key },
           as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["valid"]).to be true
      expect(json["user_id"]).to eq(user.id)
      expect(json["display_name"]).to eq(user.display_name)
    end

    it "returns invalid for expired token" do
      token = JwtService.encode({ user_id: user.id }, expiration: -1.hour)

      post "/internal/auth/verify",
           params: { token: token },
           headers: { "X-Internal-Api-Key" => api_key },
           as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["valid"]).to be false
    end

    it "returns 401 without api key" do
      post "/internal/auth/verify",
           params: { token: "anything" },
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
