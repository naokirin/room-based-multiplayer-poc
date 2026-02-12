class CreateMatches < ActiveRecord::Migration[8.1]
  def change
    create_table :matches, id: :string, limit: 36 do |t|
      t.references :game_type, null: false, type: :string, limit: 36, foreign_key: true
      t.references :room, type: :string, limit: 36, foreign_key: true
      t.integer :status, null: false, default: 0
      t.datetime :matched_at

      t.timestamps
    end

    add_index :matches, :status
  end
end
