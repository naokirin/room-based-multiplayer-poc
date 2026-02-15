# frozen_string_literal: true

class FixAuditLogsPrimaryKeyToUuid < ActiveRecord::Migration[8.1]
  def up
    return if column_type_is_string?

    execute <<-SQL.squish
      ALTER TABLE audit_logs MODIFY id VARCHAR(36) NOT NULL
    SQL
  end

  def down
    return if column_type_is_integer?

    execute <<-SQL.squish
      ALTER TABLE audit_logs MODIFY id BIGINT NOT NULL AUTO_INCREMENT
    SQL
  end

  private

  def column_type_is_string?
    type = connection.columns(:audit_logs).find { |c| c.name == "id" }&.sql_type
    type.to_s.include?("varchar") || type.to_s.include?("char")
  end

  def column_type_is_integer?
    type = connection.columns(:audit_logs).find { |c| c.name == "id" }&.sql_type
    type.to_s.include?("int") || type.to_s.include?("bigint")
  end
end
