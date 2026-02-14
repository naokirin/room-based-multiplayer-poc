module Admin
  class AnnouncementsController < ApplicationController
    before_action :set_announcement, only: [:show, :edit, :update, :destroy]

    # GET /admin/announcements
    def index
      @announcements = Announcement.includes(:admin).order(created_at: :desc)
    end

    # GET /admin/announcements/:id
    def show
    end

    # GET /admin/announcements/new
    def new
      @announcement = Announcement.new
    end

    # POST /admin/announcements
    def create
      @announcement = Announcement.new(announcement_params)
      @announcement.admin = current_admin

      if @announcement.save
        redirect_to admin_announcement_path(@announcement), notice: "Announcement created successfully"
      else
        render :new, status: :unprocessable_entity
      end
    end

    # GET /admin/announcements/:id/edit
    def edit
    end

    # PATCH/PUT /admin/announcements/:id
    def update
      if @announcement.update(announcement_params)
        redirect_to admin_announcement_path(@announcement), notice: "Announcement updated successfully"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    # DELETE /admin/announcements/:id
    def destroy
      @announcement.destroy
      redirect_to admin_announcements_path, notice: "Announcement deleted"
    end

    private

    def set_announcement
      @announcement = Announcement.find(params[:id])
    end

    def announcement_params
      params.require(:announcement).permit(:title, :body, :published_at, :expires_at, :active)
    end
  end
end
