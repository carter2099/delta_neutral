Rails.application.routes.draw do
  # Authentication
  resource :session
  resources :passwords, param: :token

  # Dashboard
  root "dashboard#show"

  # Positions
  resources :positions do
    member do
      post :rebalance
      post :sync
    end
    resource :hedge_configuration, only: [:show, :edit, :update]
  end

  # Rebalance history
  resources :rebalance_events, only: [:index, :show]

  # Settings
  get "settings" => "settings#show"
  patch "settings" => "settings#update"
  post "settings/reset_circuit_breaker" => "settings#reset_circuit_breaker"

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check
end
