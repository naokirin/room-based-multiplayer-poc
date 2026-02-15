module Api
  module V1
    class AnnouncementsController < ApplicationController
      skip_before_action :authenticate_user!, only: [ :index ]

      # GET /api/v1/announcements
      def index
        announcements = Announcement.visible.order(published_at: :desc).limit(20)
        payload = OpenStruct.new(announcements: announcements)
        render_with_serializer(Api::V1::AnnouncementsIndexSerializer, payload, root_key: :default)
      end
    end
  end
end
