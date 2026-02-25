Rails.application.routes.draw do
  mount ActionCable.server => "/cable"

  get "up" => "rails/health#show", as: :rails_health_check

  root "lobby#index"

  resources :sessions, only: %i[create show] do
    post :join, on: :member
  end

  namespace :api do
    resources :sessions, only: %i[show]
  end
end
