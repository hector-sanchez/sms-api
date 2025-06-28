require 'rails_helper'

RSpec.describe 'Auths', type: :request do
  let!(:user) { User.create!(email: 'test@example.com', password: 'password123') }
  
  before do
    # Clear database except for our test user
    User.where.not(id: user.id).delete_all
    
    # Mock environment variable for JWT
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('JWT_SECRET').and_return('test_secret_key')
  end

  describe 'POST /auths' do
    let(:valid_params) do
      {
        email: 'test@example.com',
        password: 'password123'
      }
    end

    let(:invalid_email_params) do
      {
        email: 'wrong@example.com',
        password: 'password123'
      }
    end

    let(:invalid_password_params) do
      {
        email: 'test@example.com',
        password: 'wrongpassword'
      }
    end

    context 'with valid credentials' do
      it 'authenticates user and returns token with user data' do
        post '/auths', params: valid_params

        expect(response).to have_http_status(:ok)
        
        response_body = JSON.parse(response.body)
        expect(response_body).to have_key('token')
        expect(response_body).to have_key('user')
        expect(response_body).to have_key('message')
        expect(response_body['message']).to eq('Authentication successful')

        # Verify user data
        user_data = response_body['user']
        expect(user_data['id']).to eq(user.id.to_s)
        expect(user_data['email']).to eq('test@example.com')
        expect(user_data['token_version']).to eq(user.token_version)

        # Verify token can be decoded
        token = response_body['token']
        decoded_payload = JwtService.decode(token)
        expect(decoded_payload[:user_id]).to eq(user.id.to_s)
        expect(decoded_payload[:token_version]).to eq(user.token_version)
      end

      it 'returns a valid JWT token' do
        post '/auths', params: valid_params

        response_body = JSON.parse(response.body)
        token = response_body['token']

        expect(token).to be_present
        
        # Token should be decodable
        expect { JwtService.decode(token) }.not_to raise_error
      end
    end

    context 'with invalid credentials' do
      it 'returns error for invalid email' do
        post '/auths', params: invalid_email_params

        expect(response).to have_http_status(:unauthorized)
        
        response_body = JSON.parse(response.body)
        expect(response_body).to have_key('error')
        expect(response_body).to have_key('message')
        expect(response_body['error']).to eq('Invalid email or password')
        expect(response_body['message']).to eq('Authentication failed')
        expect(response_body).not_to have_key('token')
      end

      it 'returns error for invalid password' do
        post '/auths', params: invalid_password_params

        expect(response).to have_http_status(:unauthorized)
        
        response_body = JSON.parse(response.body)
        expect(response_body).to have_key('error')
        expect(response_body).to have_key('message')
        expect(response_body['error']).to eq('Invalid email or password')
        expect(response_body['message']).to eq('Authentication failed')
        expect(response_body).not_to have_key('token')
      end

      it 'returns error for missing email' do
        post '/auths', params: { password: 'password123' }

        expect(response).to have_http_status(:unauthorized)
        
        response_body = JSON.parse(response.body)
        expect(response_body['error']).to eq('Invalid email or password')
      end

      it 'returns error for missing password' do
        post '/auths', params: { email: 'test@example.com' }

        expect(response).to have_http_status(:unauthorized)
        
        response_body = JSON.parse(response.body)
        expect(response_body['error']).to eq('Invalid email or password')
      end

      it 'returns error for empty parameters' do
        post '/auths', params: {}

        expect(response).to have_http_status(:unauthorized)
        
        response_body = JSON.parse(response.body)
        expect(response_body['error']).to eq('Invalid email or password')
      end
    end

    context 'edge cases' do
      it 'handles case-sensitive email' do
        post '/auths', params: { email: 'TEST@EXAMPLE.COM', password: 'password123' }

        expect(response).to have_http_status(:unauthorized)
        
        response_body = JSON.parse(response.body)
        expect(response_body['error']).to eq('Invalid email or password')
      end

      it 'handles extra whitespace in email' do
        post '/auths', params: { email: ' test@example.com ', password: 'password123' }

        expect(response).to have_http_status(:unauthorized)
        
        response_body = JSON.parse(response.body)
        expect(response_body['error']).to eq('Invalid email or password')
      end

      it 'handles SQL injection attempts' do
        post '/auths', params: { email: "'; DROP TABLE users; --", password: 'password123' }

        expect(response).to have_http_status(:unauthorized)
        
        response_body = JSON.parse(response.body)
        expect(response_body['error']).to eq('Invalid email or password')
      end
    end

    context 'service errors' do
      it 'handles JWT encoding errors gracefully' do
        allow(JwtService).to receive(:encode).and_raise(StandardError.new('JWT encoding failed'))

        post '/auths', params: valid_params

        expect(response).to have_http_status(:internal_server_error)
        
        response_body = JSON.parse(response.body)
        expect(response_body['error']).to eq('Authentication failed')
        expect(response_body['message']).to eq('Authentication failed')
      end
    end

    context 'content type handling' do
      it 'accepts application/json content type' do
        post '/auths',
             params: valid_params.to_json,
             headers: { 'CONTENT_TYPE' => 'application/json' }

        expect(response).to have_http_status(:ok)
      end

      it 'accepts form-encoded parameters' do
        post '/auths', params: valid_params

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'DELETE /auths' do
    let(:valid_token) do
      payload = { user_id: user.id.to_s, token_version: user.token_version }
      JwtService.encode(payload)
    end

    let(:invalid_token) { 'invalid.jwt.token' }

    context 'with valid authentication' do
      it 'logs out user successfully' do
        original_token_version = user.token_version

        delete '/auths', headers: { 'Authorization' => "Bearer #{valid_token}" }

        expect(response).to have_http_status(:ok)
        
        response_body = JSON.parse(response.body)
        expect(response_body).to have_key('message')
        expect(response_body['message']).to eq('Logout successful')

        # Verify token version was incremented
        user.reload
        expect(user.token_version).to eq(original_token_version + 1)
      end

      it 'invalidates the current token' do
        delete '/auths', headers: { 'Authorization' => "Bearer #{valid_token}" }
        expect(response).to have_http_status(:ok)

        # Try to use the same token again - should fail
        delete '/auths', headers: { 'Authorization' => "Bearer #{valid_token}" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized for missing token' do
        delete '/auths'

        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns unauthorized for invalid token' do
        delete '/auths', headers: { 'Authorization' => "Bearer #{invalid_token}" }

        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns unauthorized for malformed Authorization header' do
        delete '/auths', headers: { 'Authorization' => "InvalidFormat #{valid_token}" }

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'error handling' do
      it 'handles database errors gracefully' do
        allow_any_instance_of(User).to receive(:inc).and_raise(StandardError.new('Database error'))

        delete '/auths', headers: { 'Authorization' => "Bearer #{valid_token}" }

        expect(response).to have_http_status(:unprocessable_entity)
        
        response_body = JSON.parse(response.body)
        expect(response_body['error']).to eq('Logout failed')
        expect(response_body['message']).to eq('Authentication failed')
      end
    end
  end
end
