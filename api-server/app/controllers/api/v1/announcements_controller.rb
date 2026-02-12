module Api
  module V1
    class AnnouncementsController < ApplicationController
      skip_before_action :authenticate_user!, only: [:index]

      # GET /api/v1/announcements
      def index
        announcements = Announcement.visible.order(published_at: :desc).limit(20)
        render json: {
          announcements: announcements.map { |a|
            {
              id: a.id,
              title: a.title,
              body: a.body,
              published_at: a.published_at.iso8601
            }
          }
        }
      end
    end
  end
end
