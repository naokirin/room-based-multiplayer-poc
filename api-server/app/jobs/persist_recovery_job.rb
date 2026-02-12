class PersistRecoveryJob < ApplicationJob
  queue_as :default

  STALE_THRESHOLD = 30.minutes

  def perform
    cursor = "0"
    recovered = 0
    stale = 0

    loop do
      cursor, keys = REDIS.scan(cursor, match: "persist_failed:*", count: 100)

      keys.each do |key|
        process_key(key).tap do |result|
          recovered += 1 if result == :recovered
          stale += 1 if result == :stale
        end
      end

      break if cursor == "0"
    end

    Rails.logger.info("[PersistRecoveryJob] Processed: recovered=#{recovered}, stale=#{stale}")
  end

  private

  def process_key(key)
    data = REDIS.get(key)
    return unless data

    payload = JSON.parse(data)
    room_id = key.delete_prefix("persist_failed:")

    # Check if stale (key age > 30 minutes via TTL)
    ttl = REDIS.ttl(key)
    max_ttl = 7.days.to_i
    age_seconds = max_ttl - ttl
    if age_seconds > STALE_THRESHOLD.to_i
      Rails.logger.warn("[PersistRecoveryJob] Stale key detected: #{key} (age: #{age_seconds}s)")
      return :stale
    end

    room = Room.find_by(id: room_id)
    unless room
      REDIS.del(key)
      return :recovered
    end

    # Try to persist the result
    ActiveRecord::Base.transaction do
      room.update!(status: :finished, finished_at: payload["finished_at"])

      GameResult.create!(
        room: room,
        winner_id: payload["winner_id"],
        result_data: payload["result_data"],
        turns_played: payload.dig("result_data", "turns_played"),
        duration_seconds: payload.dig("result_data", "duration_seconds")
      )
    end

    REDIS.del(key)
    :recovered
  rescue StandardError => e
    Rails.logger.error("[PersistRecoveryJob] Failed to recover #{key}: #{e.message}")
    nil
  end
end
