# frozen_string_literal: true

FactoryBot.define do
  factory :audit_log do
    action { "test.action" }
    actor_type { :system }
    ip_address { "127.0.0.1" }
  end
end
