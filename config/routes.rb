Rails.application.routes.draw do
  # root "posts#index"
  resources :users, only: [:create] do
    resources :messages, only: [:index]
  end
  resource :auths, only: [:create, :destroy]
  resources :messages, only: [:create]
end
