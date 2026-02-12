class AuditLog < ApplicationRecord
  before_create :set_uuid

  enum :actor_type, { user: 0, admin: 1, system: 2 }

  validates :action, presence: true
  validates :actor_type, presence: true

  private

  def set_uuid
    self.id ||= SecureRandom.uuid
  end
end
