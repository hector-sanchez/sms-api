Rails.application.routes.draw do
  # root "posts#index"
  resources :users, only: [:create]
  resource :auths, only: [:create, :destroy]
end
