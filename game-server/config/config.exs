# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :game_server,
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :game_server, GameServerWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: GameServerWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: GameServer.PubSub,
  live_view: [signing_salt: "/kSwgcGx"]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Disable Tesla deprecation warning
config :tesla, disable_deprecated_builder_warning: true

# Configure Tesla adapter
config :tesla, adapter: Tesla.Adapter.Finch

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
