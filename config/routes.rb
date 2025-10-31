Rails.application.routes.draw do
  # Redirect root to scoped path
  get "/", to: redirect("/chromatic")

  scope path: '/chromatic' do
    root "games#index"

    resources :games, only: [:index, :show, :create] do
      member do
        post :play_card
        post :end_turn
        post :continue_round
      end
    end

    # Business metrics API for app_monitor
    namespace :api do
      resource :metrics, only: [:show]
    end

    get "up" => "rails/health#show", as: :rails_health_check
  end
end
