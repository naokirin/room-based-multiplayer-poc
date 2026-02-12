require "rails_helper"

RSpec.describe "Api::V1::Auth", type: :request do
  describe "POST /api/v1/auth/register" do
    let(:valid_params) do
      { user: { email: "new@example.com", password: "password123", display_name: "NewUser" } }
    end

    it "creates a new user and returns token" do
      post "/api/v1/auth/register", params: valid_params, as: :json

      expect(response).to have_http_status(:created)
      json = response.parsed_body
      expect(json["user"]["email"]).to eq("new@example.com")
      expect(json["user"]["display_name"]).to eq("NewUser")
      expect(json["access_token"]).to be_present
      expect(json["expires_at"]).to be_present
    end

    it "returns 422 for duplicate email" do
      create(:user, email: "new@example.com")
      post "/api/v1/auth/register", params: valid_params, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      json = response.parsed_body
      expect(json["errors"]["email"]).to include("has already been taken")
    end

    it "returns 422 for short password" do
      post "/api/v1/auth/register",
           params: { user: { email: "test@example.com", password: "short", display_name: "Test" } },
           as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST /api/v1/auth/login" do
    let!(:user) { create(:user, email: "test@example.com", password: "password123") }

    it "returns token for valid credentials" do
      post "/api/v1/auth/login", params: { email: "test@example.com", password: "password123" }, as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["user"]["id"]).to eq(user.id)
      expect(json["user"]["role"]).to eq("player")
      expect(json["user"]["status"]).to eq("active")
      expect(json["access_token"]).to be_present
    end

    it "returns 401 for invalid password" do
      post "/api/v1/auth/login", params: { email: "test@example.com", password: "wrong" }, as: :json

      expect(response).to have_http_status(:unauthorized)
      json = response.parsed_body
      expect(json["error"]).to eq("invalid_credentials")
    end

    it "returns 401 for frozen account" do
      user.freeze_account!(reason: "test")
      post "/api/v1/auth/login", params: { email: "test@example.com", password: "password123" }, as: :json

      expect(response).to have_http_status(:unauthorized)
      json = response.parsed_body
      expect(json["error"]).to eq("account_frozen")
    end
  end

  describe "POST /api/v1/auth/refresh" do
    let(:user) { create(:user) }
    let(:token) { JwtService.encode({ user_id: user.id }) }

    it "returns a new token" do
      post "/api/v1/auth/refresh", headers: { "Authorization" => "Bearer #{token}" }, as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["access_token"]).to be_present
      expect(json["expires_at"]).to be_present
    end

    it "returns 401 without token" do
      post "/api/v1/auth/refresh", as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/profile" do
    let(:user) { create(:user) }
    let(:token) { JwtService.encode({ user_id: user.id }) }

    it "returns current user profile" do
      get "/api/v1/profile", headers: { "Authorization" => "Bearer #{token}" }, as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["user"]["id"]).to eq(user.id)
      expect(json["user"]["email"]).to eq(user.email)
      expect(json["user"]["created_at"]).to be_present
    end
  end
end
