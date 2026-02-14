class Announcement < ApplicationRecord
  belongs_to :admin, class_name: "User"

  validates :title, presence: true, length: { maximum: 255 }
  validates :body, presence: true
  validate :expires_at_after_published_at, if: -> { published_at.present? && expires_at.present? }

  scope :active, -> { where(active: true) }
  scope :published, -> { where.not(published_at: nil).where("published_at <= ?", Time.current) }
  scope :not_expired, -> { where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :visible, -> { active.published.not_expired }

  private

  def expires_at_after_published_at
    return if expires_at > published_at

    errors.add(:expires_at, "must be after published_at")
  end
end
