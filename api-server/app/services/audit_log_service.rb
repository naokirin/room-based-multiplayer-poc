class AuditLogService
  class << self
    def log(action:, actor: nil, actor_type: :system, target: nil, metadata: nil, ip_address: nil)
      AuditLog.create!(
        actor_id: actor&.id || actor,
        actor_type: actor_type,
        action: action,
        target_type: target&.class&.name,
        target_id: target&.id || target,
        metadata: metadata,
        ip_address: ip_address
      )
    rescue StandardError => e
      Rails.logger.error("AuditLog failed: #{e.message}")
    end
  end
end
