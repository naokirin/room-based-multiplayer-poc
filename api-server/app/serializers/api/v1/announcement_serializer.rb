# frozen_string_literal: true

module Api
  module V1
    # Single announcement for GET /api/v1/announcements.
    class AnnouncementSerializer
      include Alba::Resource

      attributes id: %i[String],
                 title: %i[String],
                 body: %i[String]
      attribute :published_at do |announcement|
        announcement.published_at&.iso8601
      end
    end
  end
end
