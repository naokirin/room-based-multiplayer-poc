class Room < ApplicationRecord
  belongs_to :game_type
  has_many :room_players, dependent: :destroy
  has_many :users, through: :room_players
  has_one :game_result, dependent: :destroy
  has_one :match, dependent: :nullify

  enum :status, {
    preparing: 0,
    ready: 1,
    playing: 2,
    finished: 3,
    aborted: 4,
    failed: 5
  }

  validates :player_count, presence: true, numericality: { greater_than: 0 }
end
