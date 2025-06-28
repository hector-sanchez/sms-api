class ApplicationController < ActionController::API
  def current_user
    header = request.headers['Authorization']
    return unless header

    # Check for proper Bearer format
    return unless header.start_with?('Bearer ')

    token = header.split(' ').last
    decoded = JwtService.decode(token)
    return unless decoded

    user = User.where(id: decoded[:user_id]).first
    return unless user && decoded[:token_version].to_i == user.token_version

    @current_user ||= user
  rescue StandardError => e
    Rails.logger.error "Authentication error: #{e.message}"
    nil
  end

  def authenticate_user!
    render json: { error: 'Unauthorized' }, status: :unauthorized unless current_user
  end
end
