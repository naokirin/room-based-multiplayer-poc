module Api
  module V1
    class HealthController < ApplicationController
      skip_before_action :authenticate_user!, only: [:show]

      def show
        db_status = check_database
        redis_status = check_redis
        overall = (db_status == "ok" && redis_status == "ok") ? "ok" : "degraded"
        status_code = overall == "ok" ? :ok : :service_unavailable

        render json: {
          status: overall,
          services: {
            database: db_status,
            redis: redis_status
          }
        }, status: status_code
      end

      private

      def check_database
        ActiveRecord::Base.connection.execute("SELECT 1")
        "ok"
      rescue StandardError
        "error"
      end

      def check_redis
        REDIS.ping
        "ok"
      rescue StandardError
        "error"
      end
    end
  end
end
