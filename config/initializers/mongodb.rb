# MongoDB configuration for production environment
if Rails.env.production?
  # Additional MongoDB connection options are configured in mongoid.yml
  Rails.logger.info("MongoDB Atlas SSL configuration loaded for production")
end
