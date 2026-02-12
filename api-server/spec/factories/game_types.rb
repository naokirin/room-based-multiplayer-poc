FactoryBot.define do
  factory :game_type do
    sequence(:name) { |n| "game_type_#{n}" }
    player_count { 2 }
    turn_time_limit { 60 }
    active { true }
  end
end
