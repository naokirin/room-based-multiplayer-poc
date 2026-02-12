require "rails_helper"

RSpec.describe Room, type: :model do
  describe "validations" do
    subject { build(:room) }

    it { is_expected.to be_valid }

    it "requires player_count" do
      subject.player_count = nil
      expect(subject).not_to be_valid
    end
  end

  describe "enums" do
    it "defines statuses" do
      expect(Room.statuses.keys).to contain_exactly(
        "preparing", "ready", "playing", "finished", "aborted", "failed"
      )
    end
  end

  describe "associations" do
    it "belongs to game_type" do
      expect(Room.reflect_on_association(:game_type).macro).to eq(:belongs_to)
    end

    it "has many room_players" do
      expect(Room.reflect_on_association(:room_players).macro).to eq(:has_many)
    end
  end
end
