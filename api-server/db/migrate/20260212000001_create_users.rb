class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users, id: :string, limit: 36 do |t|
      t.string :email, null: false, limit: 255
      t.string :password_digest, null: false, limit: 255
      t.string :display_name, null: false, limit: 50
      t.integer :role, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.datetime :frozen_at
      t.text :frozen_reason

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :display_name
    add_index :users, :status
  end
end
