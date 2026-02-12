class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  self.implicit_order_column = :created_at

  before_create :set_uuid_id

  private

  def set_uuid_id
    self.id = SecureRandom.uuid if id.blank? && self.class.columns_hash["id"]&.type == :string
  end
end
