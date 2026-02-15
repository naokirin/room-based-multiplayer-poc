# frozen_string_literal: true

# 設定の取得は config/x/*.yml を config_for で読み、Setting.xxx で参照する。
# config_for の API を直接使わず、このモジュール経由で統一する。
class Setting
  class << self
    # --- Matchmaking (config/x/matchmaking.yml) ---
    def matchmaking_user_ttl_seconds
      x(:matchmaking)[:user_ttl_seconds]
    end

    def matchmaking_queue_timeout_seconds
      x(:matchmaking)[:queue_timeout_seconds]
    end

    # --- Auth (config/x/auth.yml) ---
    # 秒数。呼び出し側で .seconds して利用する（例: Setting.jwt_expiration_seconds.seconds.from_now）
    def jwt_expiration_seconds
      x(:auth)[:jwt_expiration_seconds]
    end

    # --- Game server (config/x/game_server.yml) ---
    # 注意: game-server の Phoenix ポート・client の DEFAULT_GAME_SERVER_WS_PORT と揃えること。
    def default_game_server_ws_port
      x(:game_server)[:default_ws_port]
    end

    # ENV["GAME_SERVER_WS_URL"] があればそれ、なければ localhost:default_game_server_ws_port の URL を返す。
    def game_server_ws_url
      ENV["GAME_SERVER_WS_URL"].presence || default_game_server_ws_url
    end

    def default_game_server_ws_url
      "ws://localhost:#{default_game_server_ws_port}/socket"
    end

    # --- Admin (config/x/admin.yml) ---
    def admin_per_page
      x(:admin)[:per_page]
    end

    def admin_user_game_results_limit
      x(:admin)[:user_game_results_limit]
    end

    # --- API (config/x/api.yml) ---
    def api_error_backtrace_lines
      x(:api)[:error_backtrace_lines]
    end

    def announcement_title_max_length
      x(:api)[:announcement_title_max_length]
    end

    private

    def x(name)
      @x_configs ||= {}
      @x_configs[name] ||= load_x(name)
    end

    def load_x(name)
      path = Rails.root.join("config", "x", "#{name}.yml")
      raw = Rails.application.config_for(path)
      raw.respond_to?(:with_indifferent_access) ? raw.with_indifferent_access : raw
    end
  end
end
