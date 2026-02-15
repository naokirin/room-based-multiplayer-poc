# frozen_string_literal: true

module Api
  module V1
    # GET /api/v1/health: { status, services: { database, redis } }.
    class HealthSerializer
      include Alba::Resource

      attributes status: %i[String]
      attribute :services do |obj|
        { database: obj.services.database.to_s, redis: obj.services.redis.to_s }
      end
    end
  end
end
