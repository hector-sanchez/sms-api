class UsersController < ApplicationController
  def create
    user = User.new(user_params)

    if user.save
      # Auto-authenticate the user after successful registration
      render json: success_response(user), status: :created
    else
      render json: error_response(user), status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error "User creation error: #{e.message}"
    Rails.logger.error "Backtrace: #{e.backtrace.first(5).join("\n")}"
    render json: { errors: ['User creation failed'], message: 'Registration failed' }, status: :internal_server_error
  end

  private

  def user_params
    params.permit(:email, :password)
  end

  def success_response(user)
    {
      user: user_data(user),
      token: generate_token(user),
      message: 'User created successfully'
    }
  end

  def error_response(user)
    {
      errors: user.errors.full_messages,
      message: 'User creation failed'
    }
  end

  def user_data(user)
    {
      id: user.id.to_s,
      email: user.email,
      created_at: user.created_at
    }
  end

  def generate_token(user)
    payload = {
      user_id: user.id.to_s,
      token_version: user.token_version
    }
    JwtService.encode(payload)
  end
end
