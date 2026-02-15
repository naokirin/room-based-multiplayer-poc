module Api
  module V1
    class AnnouncementsController < ApplicationController
      skip_before_action :authenticate_user!, only: [ :index ]

      # GET /api/v1/announcements
      # Returns { announcements: [...] } (client expects array at .announcements).
      def index
        announcements = Announcement.visible.order(published_at: :desc).limit(20)
        json = {
          announcements: announcements.map { |a| Api::V1::AnnouncementSerializer.new(a).as_json(root_key: nil) }
        }
        render json: json, status: :ok
      end
    end
  end
end
