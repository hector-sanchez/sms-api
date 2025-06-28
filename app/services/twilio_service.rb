class TwilioService
  VALID_STATUSES = %w[queued sent delivered].freeze

  class TwilioError < StandardError; end
  class InvalidStatusError < TwilioError; end

  def self.send_sms(to:, body:)
    raise ArgumentError, "Phone number is required" if to.blank?
    raise ArgumentError, "Message body is required" if body.blank?
    raise ArgumentError, "Message body too long (max 1600 characters)" if body.length > 1600

    client = create_client

    begin
      message = send_message(client, to: to, body: body)
      validate_message_status!(message)

      Rails.logger.info "SMS sent successfully: SID=#{message.sid}, Status=#{message.status}"
      message
    rescue InvalidStatusError, TwilioError => e
      # Re-raise our custom errors as-is without wrapping
      raise e
    rescue Twilio::REST::RestError => e
      Rails.logger.error "Twilio REST error: #{e.message} (Code: #{e.code})"
      raise TwilioError, "Twilio API error: #{e.message}"
    rescue => e
      Rails.logger.error "Unexpected error in TwilioService: #{e.message}"
      raise TwilioError, "SMS service error: #{e.message}"
    end
  end

  private

  def self.create_client
    account_sid = ENV['TWILIO_ACCOUNT_SID']
    auth_token = ENV['TWILIO_AUTH_TOKEN']

    raise TwilioError, "Twilio credentials not configured" if account_sid.blank? || auth_token.blank?

    Twilio::REST::Client.new(account_sid, auth_token)
  end

  def self.send_message(client, to:, body:)
    from_number = ENV['TWILIO_PHONE_NUMBER']
    raise TwilioError, "Twilio phone number not configured" if from_number.blank?

    client.messages.create(
      from: from_number,
      to: to,
      body: body
    )
  end

  def self.validate_message_status!(message)
    unless VALID_STATUSES.include?(message.status)
      error_msg = "Message failed with status: #{message.status}"
      Rails.logger.error error_msg
      raise InvalidStatusError, error_msg
    end
  end
end
