Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  root "dashboard#index"

  get "map", to: "maps#index"

  resources :locations, only: [:index]

  # Phase 4: Accessibility Intelligence Engine Routes
  get "accessibility", to: "accessibility#index"
  get "accessibility/:id", to: "accessibility#show", as: :accessibility_location
  post "accessibility/recalculate", to: "accessibility#recalculate", as: :recalculate_accessibility

  # Phase 5: Smart Route Planner Routes
  get "routes", to: "routes#index"
  post "routes/calculate", to: "routes#calculate", as: :calculate_routes
end
