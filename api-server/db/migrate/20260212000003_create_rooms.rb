class CreateRooms < ActiveRecord::Migration[8.1]
  def change
    create_table :rooms, id: :string, limit: 36 do |t|
      t.references :game_type, null: false, type: :string, limit: 36, foreign_key: true
      t.integer :status, null: false, default: 0
      t.string :node_name, limit: 255
      t.integer :player_count, null: false
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end

    add_index :rooms, :status
    add_index :rooms, :node_name
  end
end
