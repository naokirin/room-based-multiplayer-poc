class MatchPlayer < ApplicationRecord
  belongs_to :match
  belongs_to :user

  validates :user_id, uniqueness: { scope: :match_id }
  validates :queued_at, presence: true
end
