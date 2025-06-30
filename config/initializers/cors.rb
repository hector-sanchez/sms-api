# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    if Rails.env.development?
      # Allow all origins in development for easier testing
      origins '*'
    else
      # In production, only allow specific domains
      origins ENV['FRONTEND_URL'] || 'https://yourdomain.com',
              ENV['ADMIN_URL'] || 'https://admin.yourdomain.com'
              # Add more specific domains as needed
    end

    resource '*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true
  end
end
