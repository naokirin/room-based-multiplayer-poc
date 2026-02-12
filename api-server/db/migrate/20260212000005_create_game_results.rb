class CreateGameResults < ActiveRecord::Migration[8.1]
  def change
    create_table :game_results, id: :string, limit: 36 do |t|
      t.references :room, null: false, type: :string, limit: 36, foreign_key: true, index: { unique: true }
      t.references :winner, type: :string, limit: 36, foreign_key: { to_table: :users }
      t.json :result_data
      t.integer :turns_played, null: false
      t.integer :duration_seconds, null: false

      t.timestamps
    end
  end
end
