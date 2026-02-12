module Auditable
  extend ActiveSupport::Concern

  private

  # Log a security-relevant action to the audit_logs table and Rails logger.
  #
  #   audit_log(action: "user.login.success", target: user)
  #   audit_log(action: "admin.user.freeze", target: @user, metadata: { reason: "spam" })
  #
  # +action+   – dot-separated action name (e.g. "user.login.success")
  # +target+   – optional ActiveRecord object being acted upon
  # +metadata+ – optional Hash of extra context
  def audit_log(action:, target: nil, metadata: {})
    actor = resolve_actor
    actor_id = actor&.id
    actor_type = resolve_actor_type(actor)

    record = AuditLog.create!(
      actor_id: actor_id,
      actor_type: actor_type,
      action: action,
      target_type: target&.class&.name,
      target_id: target&.id,
      metadata: metadata.presence,
      ip_address: request.remote_ip
    )

    Rails.logger.info(
      "[AuditLog] #{action} actor=#{actor_type}:#{actor_id || 'none'} " \
      "target=#{record.target_type}:#{record.target_id} ip=#{request.remote_ip}"
    )

    record
  rescue StandardError => e
    # Audit logging must never break the main request flow
    Rails.logger.error("[AuditLog] Failed to write audit log: #{e.message}")
    nil
  end

  def resolve_actor
    if respond_to?(:current_admin, true) && current_admin
      current_admin
    elsif respond_to?(:current_user, true) && current_user
      current_user
    end
  rescue StandardError
    nil
  end

  def resolve_actor_type(actor)
    return :system unless actor

    actor.respond_to?(:admin?) && actor.admin? ? :admin : :user
  end
end
