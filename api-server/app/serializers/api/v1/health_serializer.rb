# frozen_string_literal: true

module Api
  module V1
    # GET /api/v1/health: { status, services: { database, redis } }.
    class HealthSerializer
      include Alba::Resource

      attributes status: %i[String]
      nested_attribute :services do
        attributes database: %i[String],
                   redis: %i[String]
      end
    end
  end
end
