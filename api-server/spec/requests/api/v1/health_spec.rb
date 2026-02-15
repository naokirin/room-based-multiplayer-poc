# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Health", type: :request do
  describe "GET /api/v1/health" do
    before do
      allow_any_instance_of(Api::V1::HealthController).to receive(:check_database).and_return("ok")
      allow_any_instance_of(Api::V1::HealthController).to receive(:check_redis).and_return("ok")
    end

    it "returns ok and expected response format (status, services)" do
      get "/api/v1/health", as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json).to have_key("status")
      expect(json["status"]).to be_a(String)
      expect(json).to have_key("services")
      expect(json["services"]).to be_a(Hash)
      expect(json["services"]).to have_key("database")
      expect(json["services"]).to have_key("redis")
      expect(json["services"]["database"]).to be_a(String)
      expect(json["services"]["redis"]).to be_a(String)
    end
  end
end
