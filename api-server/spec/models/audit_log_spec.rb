# frozen_string_literal: true

require "rails_helper"

RSpec.describe AuditLog, type: :model do
  let(:uuid_format) { /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i }

  describe "id assignment" do
    it "assigns a UUID to id on create" do
      log = described_class.create!(action: "test.action", actor_type: :system)

      expect(log.id).to match(uuid_format)
    end

    it "allows creating multiple records with distinct UUIDs (no duplicate key)" do
      logs = 5.times.map do
        described_class.create!(action: "test.action", actor_type: :system)
      end

      ids = logs.map(&:id)
      expect(ids.uniq).to eq(ids)
      ids.each { |id| expect(id).to match(uuid_format) }
    end
  end

  describe "validations" do
    it "requires action" do
      log = build(:audit_log, action: nil)
      expect(log).not_to be_valid
      expect(log.errors[:action]).to include("can't be blank")
    end

    it "requires actor_type" do
      log = build(:audit_log, actor_type: nil)
      expect(log).not_to be_valid
      expect(log.errors[:actor_type]).to include("can't be blank")
    end
  end

  describe "enums" do
    it "defines actor_type" do
      expect(described_class.actor_types).to eq("user" => 0, "admin" => 1, "system" => 2)
    end
  end
end
