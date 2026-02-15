class CreateMatchPlayers < ActiveRecord::Migration[8.1]
  def change
    create_table :match_players, id: :string, limit: 36 do |t|
      t.references :match, null: false, type: :string, limit: 36, foreign_key: true
      t.references :user, null: false, type: :string, limit: 36, foreign_key: true
      t.datetime :queued_at, null: false

      t.timestamps
    end

    add_index :match_players, [ :match_id, :user_id ], unique: true
  end
end
