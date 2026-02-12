class GameResult < ApplicationRecord
  belongs_to :room
  belongs_to :winner, class_name: "User", optional: true

  validates :room_id, uniqueness: true
  validates :turns_played, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :duration_seconds, presence: true, numericality: { greater_than_or_equal_to: 0 }
end
