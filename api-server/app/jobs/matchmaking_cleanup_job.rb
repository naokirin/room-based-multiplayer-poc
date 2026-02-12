class MatchmakingCleanupJob < ApplicationJob
  queue_as :default

  MATCHMAKING_TIMEOUT = 60 # seconds

  def perform
    cleanup_expired_queue_entries
  end

  private

  def cleanup_expired_queue_entries
    # Scan all matchmaking:user:* keys
    cursor = "0"
    expired_count = 0

    loop do
      cursor, keys = REDIS.scan(cursor, match: "matchmaking:user:*", count: 100)

      keys.each do |key|
        cleanup_user_if_expired(key)
        expired_count += 1
      end

      break if cursor == "0"
    end

    Rails.logger.info("MatchmakingCleanupJob: Cleaned up #{expired_count} expired entries") if expired_count > 0
  end

  def cleanup_user_if_expired(user_key)
    queue_info = REDIS.hgetall(user_key)
    return unless queue_info.present?

    queued_at_str = queue_info["queued_at"]
    return unless queued_at_str

    queued_at = Time.parse(queued_at_str)
    time_elapsed = Time.current - queued_at

    if time_elapsed > MATCHMAKING_TIMEOUT
      # Extract user_id from key (matchmaking:user:{user_id})
      user_id = user_key.split(":").last
      game_type_id = queue_info["game_type_id"]

      # Remove from queue
      remove_from_queue(user_id, game_type_id)

      # Remove user status
      REDIS.del(user_key)

      Rails.logger.info("MatchmakingCleanupJob: Removed expired entry for user #{user_id}, queued for #{time_elapsed.to_i}s")
    end
  rescue StandardError => e
    Rails.logger.error("MatchmakingCleanupJob: Error cleaning up #{user_key}: #{e.message}")
  end

  def remove_from_queue(user_id, game_type_id)
    return unless game_type_id

    queue_key = "matchmaking:queue:#{game_type_id}"
    queue_entries = REDIS.lrange(queue_key, 0, -1)

    queue_entries.each do |entry|
      parsed = JSON.parse(entry)
      if parsed["user_id"] == user_id
        REDIS.lrem(queue_key, 1, entry)
        break
      end
    end
  rescue StandardError => e
    Rails.logger.error("MatchmakingCleanupJob: Error removing from queue: #{e.message}")
  end
end
