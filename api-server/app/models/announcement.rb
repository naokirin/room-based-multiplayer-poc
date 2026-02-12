class Announcement < ApplicationRecord
  belongs_to :admin, class_name: "User"

  validates :title, presence: true, length: { maximum: 255 }
  validates :body, presence: true

  scope :active, -> { where(active: true) }
  scope :published, -> { where.not(published_at: nil).where("published_at <= ?", Time.current) }
  scope :not_expired, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :visible, -> { active.published.not_expired }
end
