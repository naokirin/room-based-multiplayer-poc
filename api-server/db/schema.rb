# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_15_000000) do
  create_table "announcements", id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "admin_id", limit: 36, null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.datetime "published_at"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["admin_id"], name: "index_announcements_on_admin_id"
  end

  create_table "audit_logs", id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "action", limit: 100, null: false
    t.string "actor_id", limit: 36
    t.integer "actor_type", null: false
    t.datetime "created_at", null: false
    t.string "ip_address", limit: 45
    t.json "metadata"
    t.string "target_id", limit: 36
    t.string "target_type", limit: 50
    t.index ["action"], name: "index_audit_logs_on_action"
    t.index ["actor_id"], name: "index_audit_logs_on_actor_id"
    t.index ["created_at"], name: "index_audit_logs_on_created_at"
    t.index ["target_id"], name: "index_audit_logs_on_target_id"
  end

  create_table "cards", id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "cost", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "effect", limit: 50, null: false
    t.string "game_type_id", limit: 36, null: false
    t.string "name", limit: 100, null: false
    t.datetime "updated_at", null: false
    t.integer "value", null: false
    t.index ["game_type_id", "active"], name: "index_cards_on_game_type_id_and_active"
    t.index ["game_type_id"], name: "index_cards_on_game_type_id"
  end

  create_table "game_results", id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "duration_seconds", null: false
    t.json "result_data"
    t.string "room_id", limit: 36, null: false
    t.integer "turns_played", null: false
    t.datetime "updated_at", null: false
    t.string "winner_id", limit: 36
    t.index ["room_id"], name: "index_game_results_on_room_id", unique: true
    t.index ["winner_id"], name: "index_game_results_on_winner_id"
  end

  create_table "game_types", id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.json "config_json"
    t.datetime "created_at", null: false
    t.string "name", limit: 100, null: false
    t.integer "player_count", null: false
    t.integer "turn_time_limit", default: 60, null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_game_types_on_name", unique: true
  end

  create_table "match_players", id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "match_id", limit: 36, null: false
    t.datetime "queued_at", null: false
    t.datetime "updated_at", null: false
    t.string "user_id", limit: 36, null: false
    t.index ["match_id", "user_id"], name: "index_match_players_on_match_id_and_user_id", unique: true
    t.index ["match_id"], name: "index_match_players_on_match_id"
    t.index ["user_id"], name: "index_match_players_on_user_id"
  end

  create_table "matches", id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "game_type_id", limit: 36, null: false
    t.datetime "matched_at"
    t.string "room_id", limit: 36
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["game_type_id"], name: "index_matches_on_game_type_id"
    t.index ["room_id"], name: "index_matches_on_room_id"
    t.index ["status"], name: "index_matches_on_status"
  end

  create_table "room_players", id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "joined_at"
    t.integer "result"
    t.string "room_id", limit: 36, null: false
    t.datetime "updated_at", null: false
    t.string "user_id", limit: 36, null: false
    t.index ["room_id", "user_id"], name: "index_room_players_on_room_id_and_user_id", unique: true
    t.index ["room_id"], name: "index_room_players_on_room_id"
    t.index ["user_id"], name: "index_room_players_on_user_id"
  end

  create_table "rooms", id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.string "game_type_id", limit: 36, null: false
    t.string "node_name"
    t.integer "player_count", null: false
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["game_type_id"], name: "index_rooms_on_game_type_id"
    t.index ["node_name"], name: "index_rooms_on_node_name"
    t.index ["status"], name: "index_rooms_on_status"
  end

  create_table "users", id: { type: :string, limit: 36 }, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "display_name", limit: 50, null: false
    t.string "email", null: false
    t.datetime "frozen_at"
    t.text "frozen_reason"
    t.string "password_digest", null: false
    t.integer "role", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["display_name"], name: "index_users_on_display_name"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["status"], name: "index_users_on_status"
  end

  add_foreign_key "announcements", "users", column: "admin_id"
  add_foreign_key "cards", "game_types"
  add_foreign_key "game_results", "rooms"
  add_foreign_key "game_results", "users", column: "winner_id"
  add_foreign_key "match_players", "matches"
  add_foreign_key "match_players", "users"
  add_foreign_key "matches", "game_types"
  add_foreign_key "matches", "rooms"
  add_foreign_key "room_players", "rooms"
  add_foreign_key "room_players", "users"
  add_foreign_key "rooms", "game_types"
end
