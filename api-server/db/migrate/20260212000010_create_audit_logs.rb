class CreateAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_logs do |t|
      t.string :actor_id, limit: 36
      t.integer :actor_type, null: false
      t.string :action, null: false, limit: 100
      t.string :target_type, limit: 50
      t.string :target_id, limit: 36
      t.json :metadata
      t.string :ip_address, limit: 45

      t.datetime :created_at, null: false
    end

    add_index :audit_logs, :actor_id
    add_index :audit_logs, :action
    add_index :audit_logs, :target_id
    add_index :audit_logs, :created_at
  end
end
