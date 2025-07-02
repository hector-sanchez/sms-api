# MongoDB SSL configuration for Heroku
if Rails.env.production?
  # Set SSL context options to handle MongoDB Atlas SSL issues on Heroku
  Mongo::Client.class_eval do
    private
    
    alias_method :original_ssl_context, :ssl_context
    
    def ssl_context(options = {})
      context = original_ssl_context(options)
      context.set_params(verify_mode: OpenSSL::SSL::VERIFY_NONE) if Rails.env.production?
      context
    end
  end
end
