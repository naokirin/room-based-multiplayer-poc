# Seed data for development and testing
# Run with: bin/rails db:seed

puts "Seeding database..."

# Admin user
admin = User.find_or_create_by!(email: "admin@example.com") do |u|
  u.password = "password"
  u.display_name = "Admin"
  u.role = :admin
end
puts "  Admin: #{admin.email}"

# Test players
player1 = User.find_or_create_by!(email: "player1@example.com") do |u|
  u.password = "password"
  u.display_name = "Player1"
end
puts "  Player1: #{player1.email}"

player2 = User.find_or_create_by!(email: "player2@example.com") do |u|
  u.password = "password"
  u.display_name = "Player2"
end
puts "  Player2: #{player2.email}"

# Game type
game_type = GameType.find_or_create_by!(name: "simple_card_battle") do |gt|
  gt.player_count = 2
  gt.turn_time_limit = 60
  gt.config_json = { max_hp: 20, initial_hand_size: 5 }
end
puts "  GameType: #{game_type.name}"

# Card definitions for simple_card_battle
cards_data = [
  { name: "Fireball", effect: "deal_damage", value: 3, cost: 0 },
  { name: "Lightning Bolt", effect: "deal_damage", value: 4, cost: 0 },
  { name: "Ice Shard", effect: "deal_damage", value: 2, cost: 0 },
  { name: "Shadow Strike", effect: "deal_damage", value: 5, cost: 0 },
  { name: "Heal", effect: "heal", value: 3, cost: 0 },
  { name: "Greater Heal", effect: "heal", value: 5, cost: 0 },
  { name: "Bandage", effect: "heal", value: 2, cost: 0 },
  { name: "Draw Power", effect: "draw_card", value: 1, cost: 0 },
  { name: "Arcane Intellect", effect: "draw_card", value: 2, cost: 0 },
  { name: "Quick Draw", effect: "draw_card", value: 1, cost: 0 }
]

cards_data.each do |card_data|
  Card.find_or_create_by!(game_type: game_type, name: card_data[:name]) do |c|
    c.effect = card_data[:effect]
    c.value = card_data[:value]
    c.cost = card_data[:cost]
  end
end
puts "  Cards: #{Card.where(game_type: game_type).count} cards created"

puts "Seeding complete!"
