Rails.application.routes.draw do
  # Health check endpoint
  get "up" => "rails/health#show", as: :rails_health_check
  
  # Root route for API info
  root to: proc { [200, {}, [{ 
    message: "SMS API is running", 
    version: "1.0.0",
    endpoints: {
      register: "POST /users",
      login: "POST /auths", 
      logout: "DELETE /auths",
      send_sms: "POST /messages",
      get_messages: "GET /users/:user_id/messages"
    }
  }.to_json]] }
  
  resources :users, only: [:create] do
    resources :messages, only: [:index]
  end
  resource :auths, only: [:create, :destroy]
  resources :messages, only: [:create]
end
