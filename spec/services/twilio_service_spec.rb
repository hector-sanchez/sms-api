require 'rails_helper'

RSpec.describe TwilioService do
  describe '.send_sms' do
    let(:to_number) { '+1234567890' }
    let(:message_body) { 'Hello, this is a test message!' }
    let(:twilio_client) { instance_double(Twilio::REST::Client) }
    let(:messages_client) { double('messages') }

    before do
      # Mock environment variables
      allow(ENV).to receive(:[]).with('TWILIO_ACCOUNT_SID').and_return('test_account_sid')
      allow(ENV).to receive(:[]).with('TWILIO_AUTH_TOKEN').and_return('test_auth_token')
      allow(ENV).to receive(:[]).with('TWILIO_PHONE_NUMBER').and_return('+1987654321')
      
      # Mock Twilio client initialization
      allow(Twilio::REST::Client).to receive(:new).and_return(twilio_client)
      allow(twilio_client).to receive(:messages).and_return(messages_client)
    end

    context 'when message is sent successfully' do
      let(:successful_response) do
        instance_double(
          "Twilio::REST::Api::V2010::AccountContext::MessageInstance",
          status: 'queued',
          sid: 'SM1234567890abcdef',
          from: '+1987654321',
          to: to_number,
          body: message_body
        )
      end

      before do
        allow(messages_client).to receive(:create).and_return(successful_response)
      end

      it 'creates a Twilio client with correct credentials' do
        TwilioService.send_sms(to: to_number, body: message_body)
        
        expect(Twilio::REST::Client).to have_received(:new).with(
          'test_account_sid',
          'test_auth_token'
        )
      end

      it 'calls the messages create method with correct parameters' do
        TwilioService.send_sms(to: to_number, body: message_body)
        
        expect(messages_client).to have_received(:create).with(
          from: '+1987654321',
          to: to_number,
          body: message_body
        )
      end

      it 'returns the message object when status is queued' do
        result = TwilioService.send_sms(to: to_number, body: message_body)
        expect(result).to eq(successful_response)
        expect(result.status).to eq('queued')
      end

      it 'returns the message object when status is sent' do
        allow(successful_response).to receive(:status).and_return('sent')
        
        result = TwilioService.send_sms(to: to_number, body: message_body)
        expect(result).to eq(successful_response)
        expect(result.status).to eq('sent')
      end

      it 'returns the message object when status is delivered' do
        allow(successful_response).to receive(:status).and_return('delivered')
        
        result = TwilioService.send_sms(to: to_number, body: message_body)
        expect(result).to eq(successful_response)
        expect(result.status).to eq('delivered')
      end
    end

    context 'when message fails with invalid status' do
      %w[failed undelivered].each do |invalid_status|
        it "raises error when status is #{invalid_status}" do
          failed_response = instance_double(
            "Twilio::REST::Api::V2010::AccountContext::MessageInstance",
            status: invalid_status
          )
          allow(messages_client).to receive(:create).and_return(failed_response)

          expect {
            TwilioService.send_sms(to: to_number, body: message_body)
          }.to raise_error(StandardError, "Message failed with status: #{invalid_status}")
        end
      end
    end

    context 'when Twilio API raises an exception' do
      it 'catches and re-raises Twilio errors with custom message' do
        # Create a mock that behaves like a Twilio::REST::RestError
        twilio_error_class = Class.new(StandardError)
        stub_const('Twilio::REST::RestError', twilio_error_class)
        
        twilio_error = twilio_error_class.new('Invalid phone number')
        allow(messages_client).to receive(:create).and_raise(twilio_error)

        expect {
          TwilioService.send_sms(to: to_number, body: message_body)
        }.to raise_error(StandardError, 'Twilio error: Invalid phone number')
      end

      it 'handles general exceptions during API calls' do
        # Test with a standard exception that could occur
        allow(messages_client).to receive(:create).and_raise(StandardError.new('Network timeout'))

        expect {
          TwilioService.send_sms(to: to_number, body: message_body)
        }.to raise_error(StandardError, 'Network timeout')
      end
    end

    context 'edge cases and validation' do
      it 'handles empty message body' do
        successful_response = instance_double(
          "Twilio::REST::Api::V2010::AccountContext::MessageInstance",
          status: 'queued'
        )
        allow(messages_client).to receive(:create).and_return(successful_response)

        result = TwilioService.send_sms(to: to_number, body: '')
        expect(result.status).to eq('queued')
      end

      it 'handles international phone numbers' do
        international_number = '+44 7911 123456'
        successful_response = instance_double(
          "Twilio::REST::Api::V2010::AccountContext::MessageInstance",
          status: 'queued'
        )
        allow(messages_client).to receive(:create).and_return(successful_response)

        result = TwilioService.send_sms(to: international_number, body: message_body)
        
        expect(messages_client).to have_received(:create).with(
          from: '+1987654321',
          to: international_number,
          body: message_body
        )
      end

      it 'handles long message bodies' do
        long_message = 'A' * 1600 # SMS standard is 160 chars, this tests long messages
        successful_response = instance_double(
          "Twilio::REST::Api::V2010::AccountContext::MessageInstance",
          status: 'queued'
        )
        allow(messages_client).to receive(:create).and_return(successful_response)

        result = TwilioService.send_sms(to: to_number, body: long_message)
        expect(result.status).to eq('queued')
      end
    end

    context 'environment variable handling' do
      it 'handles missing environment variables gracefully' do
        # Override the mocking to not mock the messages client when ENV vars are nil
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('TWILIO_ACCOUNT_SID').and_return(nil)
        allow(ENV).to receive(:[]).with('TWILIO_AUTH_TOKEN').and_return(nil)
        allow(ENV).to receive(:[]).with('TWILIO_PHONE_NUMBER').and_return(nil)
        
        # Don't mock the Twilio client creation for this test
        allow(Twilio::REST::Client).to receive(:new).and_call_original
        
        expect {
          TwilioService.send_sms(to: to_number, body: message_body)
        }.to raise_error(StandardError)
      end

      it 'uses correct environment variables' do
        successful_response = instance_double(
          "Twilio::REST::Api::V2010::AccountContext::MessageInstance",
          status: 'queued'
        )
        allow(messages_client).to receive(:create).and_return(successful_response)
        
        TwilioService.send_sms(to: to_number, body: message_body)
        
        expect(ENV).to have_received(:[]).with('TWILIO_ACCOUNT_SID')
        expect(ENV).to have_received(:[]).with('TWILIO_AUTH_TOKEN')
        expect(ENV).to have_received(:[]).with('TWILIO_PHONE_NUMBER')
      end
    end
  end
end
