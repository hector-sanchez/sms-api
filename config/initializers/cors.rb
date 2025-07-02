# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    if Rails.env.development?
      # Allow common development origins
      origins 'localhost:3000', 'localhost:3001', 'localhost:8080', 'localhost:8000',
              '127.0.0.1:3000', '127.0.0.1:3001', '127.0.0.1:8080', '127.0.0.1:8000',
              /\Ahttp:\/\/localhost:\d+\z/,
              /\Ahttp:\/\/127\.0\.0\.1:\d+\z/
    else
      # In production, allow your deployed frontend and Heroku domain
      origins 'https://6864870ddf65caf4c21cf6f4--benevolent-croquembouche-32ec43.netlify.app',
              'https://sms-api-1751415465-612b91c224a7.herokuapp.com',
              ENV['FRONTEND_URL'] || 'https://yourdomain.com',
              ENV['ADMIN_URL'] || 'https://admin.yourdomain.com'
              # Add more specific domains as needed
    end

    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true
  end
end
