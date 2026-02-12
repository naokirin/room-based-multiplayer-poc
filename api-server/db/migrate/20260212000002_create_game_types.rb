class CreateGameTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :game_types, id: :string, limit: 36 do |t|
      t.string :name, null: false, limit: 100
      t.integer :player_count, null: false
      t.integer :turn_time_limit, null: false, default: 60
      t.json :config_json
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :game_types, :name, unique: true
  end
end
