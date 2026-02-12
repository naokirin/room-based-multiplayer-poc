FactoryBot.define do
  factory :room do
    game_type
    player_count { 2 }
    status { :preparing }
  end
end
