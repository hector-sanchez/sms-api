require 'rails_helper'

RSpec.describe 'Messages', type: :request do
  let!(:user) { User.create!(email: 'test@example.com', password: 'password123') }
  let!(:other_user) { User.create!(email: 'other@example.com', password: 'password123') }
  let!(:user_messages) do
    # This will be populated by the before hook
    []
  end

  let(:valid_token) do
    payload = { user_id: user.id.to_s, token_version: user.token_version }
    JwtService.encode(payload)
  end

  let(:other_user_token) do
    payload = { user_id: other_user.id.to_s, token_version: other_user.token_version }
    JwtService.encode(payload)
  end

  let(:auth_headers) { { 'Authorization' => "Bearer #{valid_token}" } }

  before do
    # Simple cleanup - just delete all messages and recreate our test data
    Message.delete_all

    # Recreate the test messages
    user.messages.create!(body: 'Hello world', to: '+1234567890', status: 'sent')
    user.messages.create!(body: 'How are you?', to: '+1987654321', status: 'delivered')

    # Mock environment variables for JWT and Twilio
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('JWT_SECRET').and_return('test_secret_key')
    allow(ENV).to receive(:[]).with('TWILIO_ACCOUNT_SID').and_return('test_sid')
    allow(ENV).to receive(:[]).with('TWILIO_AUTH_TOKEN').and_return('test_token')
    allow(ENV).to receive(:[]).with('TWILIO_PHONE_NUMBER').and_return('+1234567890')
  end

  describe 'GET /users/:user_id/messages' do
    context 'with valid authentication' do
      it 'returns user messages in descending order' do
        get "/users/#{user.id}/messages", headers: auth_headers

        expect(response).to have_http_status(:ok)

        response_body = JSON.parse(response.body)
        expect(response_body).to have_key('messages')
        expect(response_body).to have_key('count')
        expect(response_body).to have_key('status')
        expect(response_body).to have_key('message_text')

        expect(response_body['status']).to eq('success')
        expect(response_body['message_text']).to eq('Messages retrieved successfully')
        expect(response_body['count']).to eq(2)

        messages = response_body['messages']
        expect(messages.length).to eq(2)

        # Check message structure
        first_message = messages.first
        expect(first_message).to have_key('id')
        expect(first_message).to have_key('body')
        expect(first_message).to have_key('phone_number')
        expect(first_message).to have_key('status')
        expect(first_message).to have_key('created_at')
        expect(first_message).to have_key('updated_at')

        # Should be in descending order (newest first)
        expect(messages.first['body']).to eq('How are you?')
        expect(messages.last['body']).to eq('Hello world')
      end

      it 'returns empty array for user with no messages' do
        new_user = User.create!(email: 'new@example.com', password: 'password123')
        new_token = JwtService.encode({ user_id: new_user.id.to_s, token_version: new_user.token_version })

        get "/users/#{new_user.id}/messages", headers: { 'Authorization' => "Bearer #{new_token}" }

        expect(response).to have_http_status(:ok)

        response_body = JSON.parse(response.body)
        expect(response_body['messages']).to eq([])
        expect(response_body['count']).to eq(0)
      end
    end

    context 'with invalid authentication' do
      it 'returns unauthorized for missing token' do
        get "/users/#{user.id}/messages"

        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns unauthorized for invalid token' do
        get "/users/#{user.id}/messages", headers: { 'Authorization' => 'Bearer invalid_token' }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with authorization issues' do
      it 'returns forbidden when accessing another user messages' do
        get "/users/#{other_user.id}/messages", headers: auth_headers

        expect(response).to have_http_status(:forbidden)

        response_body = JSON.parse(response.body)
        expect(response_body['error']).to eq('Access denied')
        expect(response_body['status']).to eq('error')
      end

      it 'returns not found for non-existent user' do
        fake_id = BSON::ObjectId.new
        get "/users/#{fake_id}/messages", headers: auth_headers

        expect(response).to have_http_status(:not_found)

        response_body = JSON.parse(response.body)
        expect(response_body['error']).to eq('User not found')
      end
    end
  end

  describe 'POST /messages' do
    let(:valid_message_params) do
      {
        to: '+1234567890',
        body: 'Hello from test!'
      }
    end

    let(:invalid_message_params) do
      {
        to: 'invalid_phone',
        body: ''
      }
    end

    context 'with successful SMS sending' do
      let(:mock_twilio_response) do
        double('TwilioResponse',
               status: 'queued',
               sid: 'SM1234567890abcdef',
               respond_to?: true)
      end

      before do
        allow(TwilioService).to receive(:send_sms).and_return(mock_twilio_response)
      end

      it 'creates message and sends SMS successfully' do
        expect {
          post '/messages', params: valid_message_params, headers: auth_headers
        }.to change(Message, :count).by(1)

        expect(response).to have_http_status(:created)

        response_body = JSON.parse(response.body)
        expect(response_body).to have_key('message')
        expect(response_body).to have_key('status')
        expect(response_body).to have_key('message_text')

        expect(response_body['status']).to eq('success')
        expect(response_body['message_text']).to eq('Message processed successfully')

        message_data = response_body['message']
        expect(message_data['body']).to eq('Hello from test!')
        expect(message_data['phone_number']).to eq('+1234567890')
        expect(message_data['status']).to eq('queued')
        expect(message_data['twilio_sid']).to eq('SM1234567890abcdef')

        # Verify message was saved to database
        message = Message.last
        expect(message.user).to eq(user)
        expect(message.body).to eq('Hello from test!')
        expect(message.status).to eq('queued')
        expect(message.twilio_sid).to eq('SM1234567890abcdef')
      end

      it 'creates message with pending status initially' do
        # Mock a successful build but before Twilio call
        message = user.messages.build(to: '+1234567890', body: 'Test')
        expect(message.status).to eq('pending')
      end

      it 'calls TwilioService with correct parameters' do
        post '/messages', params: valid_message_params, headers: auth_headers

        expect(TwilioService).to have_received(:send_sms).with(
          to: '+1234567890',
          body: 'Hello from test!'
        )
      end
    end

    context 'with Twilio service failure' do
      before do
        allow(TwilioService).to receive(:send_sms).and_raise(StandardError.new('Twilio API error'))
      end

      it 'saves message with failed status when Twilio fails' do
        expect {
          post '/messages', params: valid_message_params, headers: auth_headers
        }.to change(Message, :count).by(1)

        expect(response).to have_http_status(:unprocessable_entity)

        response_body = JSON.parse(response.body)
        expect(response_body['error']).to eq('Message saved but failed to send via SMS')
        expect(response_body['status']).to eq('error')

        # Verify message was saved with failed status
        message = Message.last
        expect(message.status).to eq('failed')
        expect(message.body).to eq('Hello from test!')
      end
    end

    context 'with validation errors' do
      it 'returns validation errors for invalid phone number' do
        expect {
          post '/messages', params: { to: 'invalid_phone', body: 'Test' }, headers: auth_headers
        }.not_to change(Message, :count)

        expect(response).to have_http_status(:unprocessable_entity)

        response_body = JSON.parse(response.body)
        expect(response_body).to have_key('errors')
        expect(response_body).to have_key('status')
        expect(response_body).to have_key('message_text')

        expect(response_body['status']).to eq('error')
        expect(response_body['message_text']).to eq('Validation failed')
        expect(response_body['errors']).to include('To must be a valid phone number')
      end

      it 'returns validation errors for empty body' do
        expect {
          post '/messages', params: { to: '+1234567890', body: '' }, headers: auth_headers
        }.not_to change(Message, :count)

        expect(response).to have_http_status(:bad_request)

        response_body = JSON.parse(response.body)
        expect(response_body['error']).to eq('Phone number and message body are required')
      end

      it 'returns validation errors for missing parameters' do
        expect {
          post '/messages', params: {}, headers: auth_headers
        }.not_to change(Message, :count)

        expect(response).to have_http_status(:bad_request)

        response_body = JSON.parse(response.body)
        expect(response_body['error']).to eq('Phone number and message body are required')
        expect(response_body['status']).to eq('error')
      end

      it 'returns validation errors for missing phone number only' do
        expect {
          post '/messages', params: { body: 'Test message' }, headers: auth_headers
        }.not_to change(Message, :count)

        expect(response).to have_http_status(:bad_request)
      end

      it 'returns validation errors for missing body only' do
        expect {
          post '/messages', params: { to: '+1234567890' }, headers: auth_headers
        }.not_to change(Message, :count)

        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized for missing token' do
        post '/messages', params: valid_message_params

        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns unauthorized for invalid token' do
        post '/messages',
             params: valid_message_params,
             headers: { 'Authorization' => 'Bearer invalid_token' }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'edge cases' do
      let(:mock_twilio_response) do
        double('TwilioResponse', status: 'queued', respond_to?: false)
      end

      before do
        allow(TwilioService).to receive(:send_sms).and_return(mock_twilio_response)
      end

      it 'handles Twilio response without sid gracefully' do
        post '/messages', params: valid_message_params, headers: auth_headers

        expect(response).to have_http_status(:created)

        message = Message.last
        expect(message.twilio_sid).to be_nil
        expect(message.status).to eq('queued')
      end

      it 'handles very long message bodies' do
        long_message = 'A' * 1600  # Maximum allowed length
        params = { to: '+1234567890', body: long_message }

        post '/messages', params: params, headers: auth_headers

        expect(response).to have_http_status(:created)
        expect(Message.last.body).to eq(long_message)
      end

      it 'rejects message bodies that are too long' do
        too_long_message = 'A' * 1601  # Exceeds maximum
        params = { to: '+1234567890', body: too_long_message }

        expect {
          post '/messages', params: params, headers: auth_headers
        }.not_to change(Message, :count)

        expect(response).to have_http_status(:unprocessable_entity)

        response_body = JSON.parse(response.body)
        expect(response_body['errors']).to include('Body is too long (maximum is 1600 characters)')
      end

      it 'handles international phone numbers' do
        international_params = { to: '+447911123456', body: 'International test' }

        post '/messages', params: international_params, headers: auth_headers

        expect(response).to have_http_status(:created)
        expect(Message.last.to).to eq('+447911123456')
      end
    end

    context 'content type handling' do
      let(:mock_twilio_response) do
        double('TwilioResponse', status: 'queued', sid: 'SM123', respond_to?: true)
      end

      before do
        allow(TwilioService).to receive(:send_sms).and_return(mock_twilio_response)
      end

      it 'accepts application/json content type' do
        post '/messages',
             params: valid_message_params.to_json,
             headers: auth_headers.merge({ 'CONTENT_TYPE' => 'application/json' })

        expect(response).to have_http_status(:created)
      end

      it 'accepts form-encoded parameters' do
        post '/messages', params: valid_message_params, headers: auth_headers

        expect(response).to have_http_status(:created)
      end
    end
  end
end
