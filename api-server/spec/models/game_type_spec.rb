require "rails_helper"

RSpec.describe GameType, type: :model do
  describe "validations" do
    subject { build(:game_type) }

    it { is_expected.to be_valid }

    it "requires name" do
      subject.name = nil
      expect(subject).not_to be_valid
    end

    it "requires unique name" do
      create(:game_type, name: "taken")
      subject.name = "taken"
      expect(subject).not_to be_valid
    end

    it "requires player_count > 0" do
      subject.player_count = 0
      expect(subject).not_to be_valid
    end
  end

  describe "scopes" do
    it ".active returns active game types" do
      active = create(:game_type, active: true)
      create(:game_type, active: false)

      expect(GameType.active).to eq([active])
    end
  end
end
