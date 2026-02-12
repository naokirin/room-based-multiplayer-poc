FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    display_name { "TestUser" }
    role { :player }
    status { :active }

    trait :admin do
      role { :admin }
      display_name { "Admin" }
    end

    trait :frozen do
      status { :frozen }
      frozen_at { Time.current }
      frozen_reason { "Test freeze" }
    end
  end
end
