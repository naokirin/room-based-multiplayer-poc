class Card < ApplicationRecord
  belongs_to :game_type

  validates :name, presence: true, length: { maximum: 100 }
  validates :effect, presence: true, length: { maximum: 50 }
  validates :value, presence: true
  validates :cost, presence: true

  scope :active, -> { where(active: true) }
end
