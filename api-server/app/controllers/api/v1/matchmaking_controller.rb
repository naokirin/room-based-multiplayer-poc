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
        render_join_response(result)
      end

      # GET /api/v1/matchmaking/status
      def status
        result = MatchmakingService.queue_status(current_user.id)
        render_status_response(result)
      end

      # DELETE /api/v1/matchmaking/cancel
      # game_type_id is optional; when omitted, the server resolves it from the user's queue state.
      def cancel
        result = cancel_result
        render_cancel_response(result)
      end

      private

      def render_join_response(result)
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
        render_with_serializer(Matchmaking::JoinMatchedSerializer, payload, status: :ok)
      end

      def render_join_queued(result)
        payload = build_join_queued_payload(result)
        render_with_serializer(Matchmaking::JoinQueuedSerializer, payload, status: :ok)
      end

      def render_join_already_in_game(result)
        payload = build_join_already_in_game_payload(result)
        render_with_serializer(Matchmaking::JoinAlreadyInGameSerializer, payload, status: :conflict)
      end

      def render_join_already_queued(result)
        payload = build_join_already_queued_payload(result)
        render_with_serializer(Matchmaking::JoinAlreadyQueuedSerializer, payload, status: :conflict)
      end

      def render_join_error
        payload = build_error_payload("matchmaking_error", I18n.t("api.v1.errors.matchmaking_error"))
        render_with_serializer(Api::V1::ErrorSerializer, payload, status: :internal_server_error)
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

      def render_status_response(result)
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
        render_with_serializer(Matchmaking::StatusMatchedSerializer, payload, status: :ok)
      end

      def render_status_queued(result)
        payload = build_status_queued_payload(result)
        render_with_serializer(Matchmaking::StatusQueuedSerializer, payload, status: :ok)
      end

      def render_status_timeout(result)
        payload = build_status_timeout_payload(result)
        render_with_serializer(Matchmaking::StatusTimeoutSerializer, payload, status: :ok)
      end

      def render_status_not_queued(_result)
        render_with_serializer(Matchmaking::StatusNotQueuedSerializer, nil, status: :ok)
      end

      def render_status_error
        payload = build_error_payload("status_error", I18n.t("api.v1.errors.status_error"))
        render_with_serializer(Api::V1::ErrorSerializer, payload, status: :internal_server_error)
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

      def render_cancel_response(result)
        payload = ::OpenStruct.new(user_id: result[:data][:user_id].to_s)
        render_with_serializer(Matchmaking::CancelSerializer, payload, status: :ok)
      end

      def render_matchmaking_error(error_code, message, status)
        payload = build_error_payload(error_code, message)
        render_with_serializer(Api::V1::ErrorSerializer, payload, status: status)
      end

      def build_error_payload(error_code, message)
        ::OpenStruct.new(error: error_code.to_s, message: message.to_s)
      end
    end
  end
end
