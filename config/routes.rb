Rails.application.routes.draw do
  root "dashboard#index"

  resource :session
  resources :passwords, param: :token

  resources :wallets, only: [ :index, :new, :create, :destroy ] do
    post :sync_now, on: :member
  end

  resources :positions, only: [ :index, :show ] do
    post :sync_now, on: :member
  end

  resource :settings, only: [ :edit, :update ]

  resources :hedges, except: [ :index ] do
    post :sync_now, on: :member
  end

  mount MissionControl::Jobs::Engine, at: "/jobs"

  get "up" => "rails/health#show", as: :rails_health_check
end
