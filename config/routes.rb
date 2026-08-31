Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  root "dashboard#index"

  # Public Presentation & Landing Pages (SIH 2026 Ready)
  get "landing", to: "pages#landing", as: :landing
  get "demo", to: "pages#demo", as: :demo
  get "architecture", to: "pages#architecture", as: :architecture
  get "overview", to: "pages#overview", as: :overview
  get "about", to: "pages#about", as: :about

  # Global Search
  get "search", to: "search#index", as: :search

  # Authentication & Session Routes
  get "login", to: "sessions#new", as: :login
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy", as: :logout

  # Sign Up / Registration Routes
  get "sign_up", to: "registrations#new", as: :sign_up
  post "sign_up", to: "registrations#create"

  # OmniAuth OAuth Callback Routes
  match "auth/:provider/callback", to: "omniauth_callbacks#callback", via: [:get, :post], as: :omniauth_callback
  get "auth/failure", to: "omniauth_callbacks#failure", as: :omniauth_failure

  post "demo_sso_login", to: "sessions#demo_sso_login", as: :demo_sso_login

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

  # Core ENMA AI Intelligence Modules
  get "map", to: "maps#index"
  resources :locations, only: [:index]

  # Phase 4: Accessibility Intelligence Engine Routes
  get "accessibility", to: "accessibility#index"
  post "accessibility", to: "accessibility#recalculate"
  get "accessibility/:id", to: "accessibility#show", as: :accessibility_location
  post "accessibility/recalculate", to: "accessibility#recalculate", as: :recalculate_accessibility

  # Phase 5: Smart Route Planner Routes
  get "routes", to: "routes#index"
  get "routes/geocode", to: "routes#geocode", as: :geocode_routes
  post "routes/calculate", to: "routes#calculate", as: :calculate_routes

  # Phase 6: Emergency Simulation & Disaster Response Center Routes
  resources :emergencies, only: [:index, :new, :create, :show] do
    member do
      patch :update_status
      post :generate_plan
      get :export_briefing
    end
    collection do
      post :demo_scenario
    end
  end

  # Phase 8: Warehouse & Resource Intelligence
  resources :warehouses, only: [:index, :show]

  # Field Incident Reporting (Geo-tagged Photo Reports)
  resources :incidents, only: [:index, :new, :create, :show]

  # Phase 7 / Analytics: ENMA AI Intelligence Analytics Center Routes
  get "analytics", to: "analytics#index"
  get "analytics/report", to: "analytics#report"
end
