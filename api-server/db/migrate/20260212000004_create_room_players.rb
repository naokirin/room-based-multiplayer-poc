class CreateRoomPlayers < ActiveRecord::Migration[8.1]
  def change
    create_table :room_players, id: :string, limit: 36 do |t|
      t.references :room, null: false, type: :string, limit: 36, foreign_key: true
      t.references :user, null: false, type: :string, limit: 36, foreign_key: true
      t.datetime :joined_at
      t.integer :result

      t.timestamps
    end

    add_index :room_players, [:room_id, :user_id], unique: true
  end
end
