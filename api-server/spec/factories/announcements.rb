# frozen_string_literal: true

FactoryBot.define do
  factory :announcement do
    association :admin, factory: [:user, :admin]
    title { "Test announcement" }
    body { "Body text" }
    published_at { 1.hour.ago }
    expires_at { nil }
    active { true }
  end
end
