Rails.application.routes.draw do
  # API v1 routes
  namespace :api do
    namespace :v1 do
      # Auth
      post "auth/register", to: "auth#register"
      post "auth/login", to: "auth#login"
      post "auth/refresh", to: "auth#refresh"

      # Profile
      get "profile", to: "profiles#show"

      # Matchmaking
      post "matchmaking/join", to: "matchmaking#join"
      get "matchmaking/status", to: "matchmaking#status"
      delete "matchmaking/cancel", to: "matchmaking#cancel"

      # Game types
      resources :game_types, only: [:index]

      # Rooms
      get "rooms/:id/ws_endpoint", to: "rooms#ws_endpoint"

      # Announcements
      resources :announcements, only: [:index]

      # Health
      get "health", to: "health#show"
    end
  end

  # Internal API (Phoenix → Rails)
  namespace :internal do
    post "rooms", to: "rooms#create"
    put "rooms/:room_id/started", to: "rooms#started"
    put "rooms/:room_id/finished", to: "rooms#finished"
    put "rooms/:room_id/aborted", to: "rooms#aborted"
    post "auth/verify", to: "auth#verify"
  end

  # Admin routes
  namespace :admin do
    get "login", to: "sessions#new"
    post "login", to: "sessions#create"
    delete "logout", to: "sessions#destroy"

    root to: "dashboard#index"
    resources :users, only: [:index, :show] do
      member do
        post :freeze
        post :unfreeze
      end
    end
    resources :rooms, only: [:index, :show] do
      member do
        post :terminate
      end
    end
    resources :announcements
  end

  # Health check
  get "up", to: "rails/health#show", as: :rails_health_check

  # PWA
  get "service-worker", to: "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest", to: "rails/pwa#manifest", as: :pwa_manifest
end
