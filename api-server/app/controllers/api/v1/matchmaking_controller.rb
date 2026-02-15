# frozen_string_literal: true

require "ostruct"

module Api
  module V1
    class MatchmakingController < ApplicationController
      # POST /api/v1/matchmaking/join
      def join
        game_type = GameType.active.find_by(id: params[:game_type_id])
        unless game_type
          return render_matchmaking_error("invalid_game_type", I18n.t("api.v1.errors.invalid_game_type"), :not_found)
        end

        result = MatchmakingService.join_queue(current_user.id, game_type.id)
        render **join_response(result)
      end

      # GET /api/v1/matchmaking/status
      def status
        result = MatchmakingService.queue_status(current_user.id)
        render **status_response(result)
      end

      # DELETE /api/v1/matchmaking/cancel
      # game_type_id is optional; when omitted, the server resolves it from the user's queue state.
      def cancel
        result = cancel_result
        render **cancel_response(result)
      end

      private

      def join_response(result)
        case result[:status]
        when :matched then render_join_matched(result)
        when :queued then render_join_queued(result)
        when :already_in_game then render_join_already_in_game(result)
        when :already_queued then render_join_already_queued(result)
        else render_join_error
        end
      end

      def render_join_matched(result)
        payload = build_join_matched_payload(result)
        { json: Matchmaking::JoinMatchedSerializer.new(payload).as_json(root_key: nil), status: :ok }
      end

      def render_join_queued(result)
        payload = build_join_queued_payload(result)
        { json: Matchmaking::JoinQueuedSerializer.new(payload).as_json(root_key: nil), status: :ok }
      end

      def render_join_already_in_game(result)
        payload = build_join_already_in_game_payload(result)
        { json: Matchmaking::JoinAlreadyInGameSerializer.new(payload).as_json(root_key: nil), status: :conflict }
      end

      def render_join_already_queued(result)
        payload = build_join_already_queued_payload(result)
        { json: Matchmaking::JoinAlreadyQueuedSerializer.new(payload).as_json(root_key: nil), status: :conflict }
      end

      def render_join_error
        payload = build_error_payload("matchmaking_error", I18n.t("api.v1.errors.matchmaking_error"))
        { json: Api::V1::ErrorSerializer.new(payload).as_json(root_key: nil), status: :internal_server_error }
      end

      def build_join_matched_payload(result)
        room_data = result[:data]
        ::OpenStruct.new(
          room_id: room_data[:room].id.to_s,
          room_token: room_data[:room_tokens][current_user.id].to_s,
          ws_url: room_data[:ws_url].to_s
        )
      end

      def build_join_queued_payload(result)
        data = result[:data]
        ::OpenStruct.new(
          queued_at: data[:queued_at].to_s,
          timeout_seconds: data[:timeout_seconds].to_i
        )
      end

      def build_join_already_in_game_payload(result)
        data = result[:data].transform_keys(&:to_sym)
        ::OpenStruct.new(
          room_id: data[:room_id].to_s,
          room_token: data[:room_token].to_s,
          ws_url: data[:ws_url].to_s
        )
      end

      def build_join_already_queued_payload(result)
        data = result[:data].transform_keys(&:to_sym)
        ::OpenStruct.new(queued_at: data[:queued_at].to_s)
      end

      def status_response(result)
        case result[:status]
        when :matched then render_status_matched(result)
        when :queued then render_status_queued(result)
        when :timeout then render_status_timeout(result)
        when :not_queued then render_status_not_queued(result)
        else render_status_error
        end
      end

      def render_status_matched(result)
        payload = build_status_matched_payload(result)
        { json: Matchmaking::StatusMatchedSerializer.new(payload).as_json(root_key: nil), status: :ok }
      end

      def render_status_queued(result)
        payload = build_status_queued_payload(result)
        { json: Matchmaking::StatusQueuedSerializer.new(payload).as_json(root_key: nil), status: :ok }
      end

      def render_status_timeout(result)
        payload = build_status_timeout_payload(result)
        { json: Matchmaking::StatusTimeoutSerializer.new(payload).as_json(root_key: nil), status: :ok }
      end

      def render_status_not_queued(_result)
        { json: Matchmaking::StatusNotQueuedSerializer.new(nil).as_json(root_key: nil), status: :ok }
      end

      def render_status_error
        payload = build_error_payload("status_error", I18n.t("api.v1.errors.status_error"))
        { json: Api::V1::ErrorSerializer.new(payload).as_json(root_key: nil), status: :internal_server_error }
      end

      def build_status_matched_payload(result)
        data = result[:data].transform_keys(&:to_sym)
        ::OpenStruct.new(
          room_id: data[:room_id].to_s,
          room_token: data[:room_token].to_s,
          ws_url: data[:ws_url].to_s
        )
      end

      def build_status_queued_payload(result)
        data = result[:data].transform_keys(&:to_sym)
        ::OpenStruct.new(
          queued_at: data[:queued_at].to_s,
          game_type_id: data[:game_type_id].to_s
        )
      end

      def build_status_timeout_payload(result)
        ::OpenStruct.new(message: result[:data][:message].to_s)
      end

      def cancel_result
        if params[:game_type_id].present?
          MatchmakingService.cancel_queue(current_user.id, params[:game_type_id])
        else
          MatchmakingService.cancel_queue_by_user(current_user.id)
        end
      end

      def cancel_response(result)
        payload = ::OpenStruct.new(user_id: result[:data][:user_id].to_s)
        { json: Matchmaking::CancelSerializer.new(payload).as_json(root_key: nil), status: :ok }
      end

      def render_matchmaking_error(error_code, message, status)
        payload = build_error_payload(error_code, message)
        render json: Api::V1::ErrorSerializer.new(payload).as_json(root_key: nil), status: status
      end

      def build_error_payload(error_code, message)
        ::OpenStruct.new(error: error_code.to_s, message: message.to_s)
      end
    end
  end
end
