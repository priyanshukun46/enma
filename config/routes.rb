Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
  get "health" => "health#show", as: :health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "pages#landing"
  match "/", to: "pages#landing", via: [:post]

  # Authenticated Dashboard
  get "dashboard", to: "dashboard#index", as: :dashboard

  # Public Presentation & Landing Pages (SIH 2026 Ready)
  get "landing", to: "pages#landing", as: :landing
  get "demo", to: "pages#demo", as: :demo
  get "architecture", to: "pages#architecture", as: :architecture
  get "overview", to: "pages#overview", as: :overview
  get "about", to: "pages#about", as: :about

  # Global Search & Live Auto-Suggestions
  get "search/suggestions", to: "search#suggestions", as: :search_suggestions
  get "search", to: "search#index", as: :search

  # Authentication with Devise
  devise_for :users,
             path: "",
             path_names: { sign_in: "login", sign_out: "logout", sign_up: "sign_up" },
             controllers: {
               sessions: "users/sessions",
               registrations: "users/registrations",
               omniauth_callbacks: "users/omniauth_callbacks"
             }

  devise_scope :user do
    get "login", to: "users/sessions#new", as: :login
    post "login", to: "users/sessions#create"
    match "logout", to: "users/sessions#destroy", via: [:get, :delete], as: :logout
    get "sign_up", to: "users/registrations#new", as: :sign_up
    post "sign_up", to: "users/registrations#create"
    get "signup", to: "users/registrations#new"
    post "signup", to: "users/registrations#create"
    post "demo_sso_login", to: "users/sessions#demo_sso_login", as: :demo_sso_login
  end

  # User Profile & Settings
  resource :profile, only: [:show, :update]
  resource :settings, only: [:show] do
    patch :update_password
    post :connect_sso
    delete :disconnect_sso
  end

  # Password Reset Routes
  resources :passwords, param: :token, only: [:new, :create, :edit, :update]

  # Admin Namespace (Admin User Management)
  namespace :admin do
    resources :users, only: [:index] do
      member do
        patch :update_role
      end
    end
  end

  # Core ResQWay Intelligence Modules
  get "map", to: "maps#index"
  resources :locations, only: [:index]

  # Network Connectivity Intelligence Engine Routes
  get "network", to: "network#index", as: :network
  post "network/simulate", to: "network#simulate", as: :simulate_network

  # Phase 4: Accessibility Intelligence Engine Routes
  get "accessibility", to: "accessibility#index"
  post "accessibility", to: "accessibility#recalculate"
  get "accessibility/:id", to: "accessibility#show", as: :accessibility_location
  post "accessibility/recalculate", to: "accessibility#recalculate", as: :recalculate_accessibility

  # Phase 5: Smart Route Planner Routes
  get "routes", to: "routes#index"
  get "routes/geocode", to: "routes#geocode", as: :geocode_routes
  post "routes/calculate", to: "routes#calculate", as: :calculate_routes

  # Emergency Response Module (logistics use case)
  resources :emergencies, only: [:index, :new, :create, :show] do
    member do
      patch :update_status
      post :generate_plan
      get :export_briefing
      post :send_test_email
    end
    collection do
      post :demo_scenario
    end
  end

  # Phase 8: Warehouse & Resource Intelligence
  resources :warehouses, only: [:index, :show]

  # Live Logistics, Fleet Tracking & Delivery Intelligence
  resources :vehicles
  resources :shipments do
    member do
      post :simulate
      post :confirm_reroute
    end
    collection do
      get :live_map
    end
  end
  resources :logistics_alerts, only: [:index] do
    member do
      patch :acknowledge
      patch :resolve
    end
  end

  # GPS Telemetry Ingestion API
  namespace :api do
    namespace :v1 do
      resources :vehicle_locations, only: [:create]
    end
  end

  # Field Incident Reporting (Geo-tagged Photo Reports)
  resources :incidents, only: [:index, :new, :create, :show]

  # Phase 7 / Analytics: ResQWay Intelligence Analytics Center Routes
  get "analytics", to: "analytics#index"
  get "analytics/report", to: "analytics#report"

  # Predictive Cascading Impact Intelligence Engine Dashboard
  get "intelligence/predictions", to: "intelligence#predictions", as: :intelligence_predictions

  # Autonomous Response Optimization Engine Dashboard & Human Command Feedback
  get "intelligence/response", to: "intelligence#response_plan", as: :intelligence_response
  post "intelligence/feedback", to: "intelligence#feedback", as: :intelligence_feedback

  # Unified Emergency Command & Closed-Loop Response Intelligence
  get "intelligence/command", to: "intelligence#command_center", as: :intelligence_command
  post "intelligence/command/approve", to: "intelligence#command_approve", as: :intelligence_command_approve
  post "intelligence/command/modify", to: "intelligence#command_modify", as: :intelligence_command_modify
  post "intelligence/command/reject", to: "intelligence#command_reject", as: :intelligence_command_reject
end
