# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Announcements", type: :request do
  describe "GET /api/v1/announcements" do
    it "returns ok and announcements as array (response format check)" do
      announcement = create(:announcement, title: "Welcome", body: "Hello")

      get "/api/v1/announcements", as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json).to have_key("announcements")
      expect(json["announcements"]).to be_an(Array)
      expect(json["announcements"].first).to include(
        "id" => announcement.id,
        "title" => "Welcome",
        "body" => "Hello",
        "published_at" => kind_of(String)
      )
    end

    it "returns empty array when no visible announcements" do
      get "/api/v1/announcements", as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["announcements"]).to eq([])
    end
  end
end
