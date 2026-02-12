require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
    subject { build(:user) }

    it { is_expected.to be_valid }

    it "requires email" do
      subject.email = nil
      expect(subject).not_to be_valid
    end

    it "requires unique email" do
      create(:user, email: "taken@example.com")
      subject.email = "taken@example.com"
      expect(subject).not_to be_valid
    end

    it "requires password minimum 8 characters" do
      subject.password = "short"
      expect(subject).not_to be_valid
    end

    it "requires display_name" do
      subject.display_name = nil
      expect(subject).not_to be_valid
    end
  end

  describe "enums" do
    it "defines roles" do
      expect(User.roles).to eq("player" => 0, "admin" => 1)
    end

    it "defines statuses with prefix" do
      expect(User.statuses).to eq("active" => 0, "frozen" => 1)
    end
  end

  describe "#freeze_account!" do
    let(:user) { create(:user) }

    it "freezes the account" do
      user.freeze_account!(reason: "Abuse")
      user.reload
      expect(user.status).to eq("frozen")
      expect(user.frozen_at).to be_present
      expect(user.frozen_reason).to eq("Abuse")
    end
  end

  describe "#unfreeze_account!" do
    let(:user) { create(:user, :frozen) }

    it "unfreezes the account" do
      user.unfreeze_account!
      user.reload
      expect(user.status).to eq("active")
      expect(user.frozen_at).to be_nil
    end
  end
end
