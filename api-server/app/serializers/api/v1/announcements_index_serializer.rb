# frozen_string_literal: true

module Api
  module V1
    # GET /api/v1/announcements: { announcements: [...] }.
    class AnnouncementsIndexSerializer
      include Alba::Resource

      root_key :announcements

      many :announcements, resource: AnnouncementSerializer
    end
  end
end
