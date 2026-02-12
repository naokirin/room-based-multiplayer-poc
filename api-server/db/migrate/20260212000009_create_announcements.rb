class CreateAnnouncements < ActiveRecord::Migration[8.1]
  def change
    create_table :announcements, id: :string, limit: 36 do |t|
      t.references :admin, null: false, type: :string, limit: 36, foreign_key: { to_table: :users }
      t.string :title, null: false, limit: 255
      t.text :body, null: false
      t.boolean :active, null: false, default: true
      t.datetime :published_at
      t.datetime :expires_at

      t.timestamps
    end
  end
end
