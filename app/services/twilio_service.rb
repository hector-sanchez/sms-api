class TwilioService
  VALID_STATUSES = %w[queued sent delivered]

  def self.send_sms(to:, body:)
    client = Twilio::REST::Client.new(
      ENV['TWILIO_ACCOUNT_SID'],
      ENV['TWILIO_AUTH_TOKEN']
    )

    begin
      message = client.messages.create(
        from: ENV['TWILIO_PHONE_NUMBER'],
        to: to,
        body: body
      )

      raise StandardError, "Message failed with status: #{message.status}" unless VALID_STATUSES.include?(message.status)

      message
    rescue Twilio::REST::RestError => e
      raise StandardError, "Twilio error: #{e.message}"
    end
  end
end
