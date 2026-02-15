module Admin
  class DashboardController < ApplicationController
    def index
      @total_users = User.count
      @active_rooms = Room.where(status: [ :preparing, :ready, :playing ]).count
      @games_played_today = GameResult.where("created_at >= ?", Time.current.beginning_of_day).count
      @total_rooms = Room.count
      @frozen_users = User.where(status: :frozen).count
      @published_announcements = Announcement.visible.count
    end
  end
end
