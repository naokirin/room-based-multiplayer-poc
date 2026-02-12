# frozen_string_literal: true

# Allow extra hosts from environment (e.g. Docker internal hostnames).
# Set ALLOWED_HOSTS to a comma-separated list: ALLOWED_HOSTS=api-server:3001,other.service
if ENV["ALLOWED_HOSTS"].present?
  ENV["ALLOWED_HOSTS"].split(",").map(&:strip).reject(&:empty?).each do |host|
    Rails.application.config.hosts << host
  end
end
