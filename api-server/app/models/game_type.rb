class GameType < ApplicationRecord
  has_many :rooms, dependent: :destroy
  has_many :matches, dependent: :destroy
  has_many :cards, dependent: :destroy

  validates :name, presence: true, uniqueness: true, length: { maximum: 100 }
  validates :player_count, presence: true, numericality: { greater_than: 0 }
  validates :turn_time_limit, presence: true, numericality: { greater_than: 0 }

  scope :active, -> { where(active: true) }
end
