class User < ApplicationRecord
  has_secure_password

  has_many :room_players, dependent: :destroy
  has_many :rooms, through: :room_players
  has_many :match_players, dependent: :destroy
  has_many :matches, through: :match_players
  has_many :won_games, class_name: "GameResult", foreign_key: :winner_id, dependent: :nullify, inverse_of: :winner
  has_many :announcements, foreign_key: :admin_id, dependent: :destroy, inverse_of: :admin

  enum :role, { player: 0, admin: 1 }
  enum :status, { active: 0, frozen: 1 }, prefix: :account

  validates :email, presence: true, uniqueness: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 8 }, if: -> { new_record? || password.present? }
  validates :display_name, presence: true, length: { maximum: 50 }

  def account_frozen?
    status == "frozen"
  end

  def freeze_account!(reason:)
    update!(status: :frozen, frozen_at: Time.current, frozen_reason: reason)
  end

  def unfreeze_account!
    update!(status: :active, frozen_at: nil, frozen_reason: nil)
  end
end
