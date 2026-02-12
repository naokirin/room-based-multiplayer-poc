class AuditLog < ApplicationRecord
  enum :actor_type, { user: 0, admin: 1, system: 2 }

  validates :action, presence: true
  validates :actor_type, presence: true
end
