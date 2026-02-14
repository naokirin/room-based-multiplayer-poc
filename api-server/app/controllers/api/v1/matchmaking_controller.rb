module Api
  module V1
    class MatchmakingController < ApplicationController
      # POST /api/v1/matchmaking/join
      def join
        game_type = GameType.active.find_by(id: params[:game_type_id])
        unless game_type
          return render json: {
            error: "invalid_game_type",
            message: "Game type not found or inactive"
          }, status: :not_found
        end

        result = MatchmakingService.join_queue(current_user.id, game_type.id)

        case result[:status]
        when :matched
          # Match found immediately
          room_data = result[:data]
          user_token = room_data[:room_tokens][current_user.id]
          render json: {
            status: "matched",
            room_id: room_data[:room].id,
            room_token: user_token,
            ws_url: room_data[:ws_url]
          }, status: :ok
        when :queued
          # Added to queue
          render json: {
            status: "queued",
            queued_at: result[:data][:queued_at],
            timeout_seconds: result[:data][:timeout_seconds]
          }, status: :ok
        when :already_in_game
          # User already has active game
          active_game = result[:data]
          render json: {
            status: "already_in_game",
            room_id: active_game["room_id"],
            room_token: active_game["room_token"],
            ws_url: active_game["ws_url"]
          }, status: :conflict
        when :already_queued
          # User already in queue
          render json: {
            status: "already_queued",
            queued_at: result[:data]["queued_at"]
          }, status: :conflict
        else
          render json: {
            error: "matchmaking_error",
            message: "Unknown matchmaking status"
          }, status: :internal_server_error
        end
      end

      # GET /api/v1/matchmaking/status
      def status
        result = MatchmakingService.queue_status(current_user.id)

        case result[:status]
        when :matched
          # User has active game
          active_game = result[:data]
          render json: {
            status: "matched",
            room_id: active_game["room_id"],
            room_token: active_game["room_token"],
            ws_url: active_game["ws_url"]
          }, status: :ok
        when :queued
          # User in queue
          render json: {
            status: "queued",
            queued_at: result[:data]["queued_at"],
            game_type_id: result[:data]["game_type_id"]
          }, status: :ok
        when :timeout
          # Matchmaking timed out
          render json: {
            status: "timeout",
            message: result[:data][:message]
          }, status: :ok
        when :not_queued
          # User not in queue
          render json: {
            status: "not_queued"
          }, status: :ok
        else
          render json: {
            error: "status_error",
            message: "Unable to retrieve status"
          }, status: :internal_server_error
        end
      end

      # DELETE /api/v1/matchmaking/cancel
      # game_type_id is optional; when omitted, the server resolves it from the user's queue state.
      def cancel
        result = if params[:game_type_id].present?
                   MatchmakingService.cancel_queue(current_user.id, params[:game_type_id])
                 else
                   MatchmakingService.cancel_queue_by_user(current_user.id)
                 end

        render json: {
          status: "cancelled",
          user_id: result[:data][:user_id]
        }, status: :ok
      end
    end
  end
end
