class CreateCards < ActiveRecord::Migration[8.1]
  def change
    create_table :cards, id: :string, limit: 36 do |t|
      t.references :game_type, null: false, type: :string, limit: 36, foreign_key: true
      t.string :name, null: false, limit: 100
      t.string :effect, null: false, limit: 50
      t.integer :value, null: false
      t.integer :cost, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :cards, [:game_type_id, :active]
  end
end
