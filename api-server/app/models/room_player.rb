class RoomPlayer < ApplicationRecord
  belongs_to :room
  belongs_to :user

  enum :result, { winner: 0, loser: 1, draw: 2, aborted: 3 }

  validates :user_id, uniqueness: { scope: :room_id }
end
