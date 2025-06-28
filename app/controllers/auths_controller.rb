class AuthsController < ApplicationController
  before_action :authenticate_user!, only: :destroy

  def create
    # Validate required parameters first
    unless auth_params[:email].present? && auth_params[:password].present?
      return render json: error_response('Email and password are required'), status: :unauthorized
    end

    begin
      # Find user with case-insensitive email and trimmed whitespace for better UX
      # Use .where.first instead of .find_by to avoid DocumentNotFound exception
      user = User.where(email: auth_params[:email].strip.downcase).first

      if user&.authenticate(auth_params[:password])
        render json: success_response(user), status: :ok
      else
        render json: error_response('Invalid email or password'), status: :unauthorized
      end
    rescue StandardError => e
      Rails.logger.error "Authentication error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: error_response('Authentication failed'), status: :internal_server_error
    end
  end

  def destroy
    if logout_user
      render json: { message: 'Logout successful' }, status: :ok
    else
      render json: error_response('Logout failed'), status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error "Logout error: #{e.message}"
    render json: error_response('Logout failed'), status: :internal_server_error unless performed?
  end

  private

  def auth_params
    params.permit(:email, :password)
  end

  def success_response(user)
    {
      user: user_data(user),
      token: generate_token(user),
      message: 'Authentication successful'
    }
  end

  def error_response(message)
    {
      error: message,
      message: 'Authentication failed'
    }
  end

  def user_data(user)
    {
      id: user.id.to_s,
      email: user.email,
      token_version: user.token_version
    }
  end

  def generate_token(user)
    payload = {
      user_id: user.id.to_s,
      token_version: user.token_version
    }
    JwtService.encode(payload)
  end

  def logout_user
    current_user.inc(token_version: 1)
    true
  rescue StandardError => e
    Rails.logger.error "Logout failed for user #{current_user.id}: #{e.message}"
    false
  end
end
