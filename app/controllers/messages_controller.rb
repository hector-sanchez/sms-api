class MessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user, only: [:index]
  before_action :authorize_user_access, only: [:index]
  before_action :validate_message_params, only: [:create]

  def index
    messages = @user.messages.includes(:user).order(created_at: :desc)
    render json: success_response(messages), status: :ok
  rescue StandardError => e
    Rails.logger.error "Messages index error for user #{@user&.id}: #{e.message}"
    render json: error_response('Failed to retrieve messages'), status: :internal_server_error
  end

  def create
    message = build_message

    if message.valid?
      send_and_save_message(message)
    else
      render json: validation_error_response(message), status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error "Message creation error for user #{current_user&.id}: #{e.message}"
    render json: error_response('Failed to send message'), status: :internal_server_error unless performed?
  end

  private

  def message_params
    params.permit(:to, :body)
  end

  def validate_message_params
    unless message_params[:to].present? && message_params[:body].present?
      render json: error_response('Phone number and message body are required'), status: :bad_request
      return false
    end
    true
  end

  def set_user
    @user = User.find(params[:user_id])
  rescue Mongoid::Errors::DocumentNotFound
    render json: error_response('User not found'), status: :not_found
  end

  def authorize_user_access
    return if @user == current_user
    render json: error_response('Access denied'), status: :forbidden
  end

  def build_message
    current_user.messages.build(message_params.merge(status: 'pending'))
  end

  def send_and_save_message(message)
    # Attempt to send via Twilio first
    twilio_response = send_via_twilio(message)

    # Update message with Twilio response data
    update_message_from_twilio(message, twilio_response)

    if save_message(message)
      render json: success_response(message), status: :created
    else
      render json: validation_error_response(message), status: :unprocessable_entity
    end
  rescue StandardError => e
    handle_twilio_failure(message, e)
  end

  def send_via_twilio(message)
    Rails.logger.info "Sending SMS to #{message.to} for user #{current_user.id}"
    TwilioService.send_sms(to: message.to, body: message.body)
  end

  def update_message_from_twilio(message, twilio_response)
    message.status = twilio_response.status
    message.twilio_sid = extract_twilio_sid(twilio_response)
    Rails.logger.info "SMS sent successfully with status: #{message.status}, SID: #{message.twilio_sid}"
  end

  def extract_twilio_sid(twilio_response)
    twilio_response.respond_to?(:sid) ? twilio_response.sid : nil
  end

  def save_message(message)
    success = message.save
    unless success
      Rails.logger.error "Failed to save message: #{message.errors.full_messages.join(', ')}"
    end
    success
  end

  def handle_twilio_failure(message, error)
    Rails.logger.error "Twilio service error for user #{current_user.id}: #{error.message}"

    # Mark message as failed and attempt to save
    message.status = 'failed'
    message.twilio_sid = nil

    if save_message(message)
      render json: error_response('Message saved but failed to send via SMS'), status: :unprocessable_entity
    else
      render json: validation_error_response(message), status: :unprocessable_entity
    end
  end

  def success_response(data)
    case data
    when Message
      {
        message: message_data(data),
        status: 'success',
        message_text: 'Message processed successfully'
      }
    when Array, Mongoid::Criteria
      {
        messages: data.map { |msg| message_data(msg) },
        count: data.count,
        status: 'success',
        message_text: 'Messages retrieved successfully'
      }
    end
  end

  def error_response(message)
    {
      error: message,
      status: 'error'
    }
  end

  def validation_error_response(message)
    {
      errors: message.errors.full_messages,
      status: 'error',
      message_text: 'Validation failed'
    }
  end

  def message_data(message)
    {
      id: message.id.to_s,
      body: message.body,
      phone_number: message.to,
      status: message.status,
      twilio_sid: message.twilio_sid,
      created_at: message.created_at,
      updated_at: message.updated_at
    }
  end
end
