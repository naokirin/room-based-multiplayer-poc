class Match < ApplicationRecord
  belongs_to :game_type
  belongs_to :room, optional: true
  has_many :match_players, dependent: :destroy
  has_many :users, through: :match_players

  enum :status, { queued: 0, matched: 1, cancelled: 2, timeout: 3 }
end
