require 'rails_helper'

RSpec.describe 'Users', type: :request do
  describe 'POST /users' do
    let(:valid_params) do
      {
        email: 'user@example.com',
        password: 'password123'
      }
    end

    let(:invalid_params) do
      {
        email: '',
        password: ''
      }
    end

    before do
      # Clear database
      User.delete_all

      # Mock environment variable for JWT
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('JWT_SECRET').and_return('test_secret_key')
    end

    context 'with valid parameters' do
      it 'creates a new user and returns a JWT token' do
        expect {
          post '/users', params: valid_params
        }.to change(User, :count).by(1)

        expect(response).to have_http_status(:created)

        response_body = JSON.parse(response.body)
        expect(response_body).to have_key('token')
        expect(response_body).to have_key('user')
        expect(response_body).to have_key('message')
        expect(response_body['token']).to be_present
        expect(response_body['message']).to eq('User created successfully')

        # Verify the user data in response
        user_data = response_body['user']
        expect(user_data['email']).to eq('user@example.com')
        expect(user_data['id']).to be_present
        expect(user_data['created_at']).to be_present

        # Verify the created user
        user = User.last
        expect(user.email).to eq('user@example.com')
        expect(user.authenticate('password123')).to be_truthy
      end

      it 'returns a valid JWT token that can be decoded' do
        post '/users', params: valid_params

        response_body = JSON.parse(response.body)
        token = response_body['token']

        # Decode the token to verify it contains the correct payload
        decoded_payload = JwtService.decode(token)
        user = User.last

        expect(decoded_payload[:user_id]).to eq(user.id.to_s)
        expect(decoded_payload[:token_version]).to eq(user.token_version)
        expect(decoded_payload[:exp]).to be > Time.current.to_i
      end

      it 'sets the token_version field for the user' do
        post '/users', params: valid_params

        user = User.last
        expect(user.token_version).to be_present
        expect(user.token_version).to be_a(Integer)
      end

      it 'auto-authenticates user after successful registration' do
        post '/users', params: valid_params

        expect(response).to have_http_status(:created)
        response_body = JSON.parse(response.body)

        # Should include authentication token (auto-login)
        expect(response_body['token']).to be_present
        expect(response_body['user']).to be_present
        expect(response_body['message']).to eq('User created successfully')

        # Token should be valid and contain user info
        decoded_payload = JwtService.decode(response_body['token'])
        user = User.last
        expect(decoded_payload[:user_id]).to eq(user.id.to_s)
      end

      it 'normalizes email address during registration' do
        params = { email: '  TEST@Example.COM  ', password: 'password123' }

        post '/users', params: params

        expect(response).to have_http_status(:created)
        user = User.last
        expect(user.email).to eq('test@example.com')

        # Response should show normalized email
        response_body = JSON.parse(response.body)
        expect(response_body['user']['email']).to eq('test@example.com')
      end
    end

    context 'with invalid parameters' do
      it 'does not create a user when email is missing' do
        expect {
          post '/users', params: { password: 'password123' }
        }.not_to change(User, :count)

        expect(response).to have_http_status(:unprocessable_entity)

        response_body = JSON.parse(response.body)
        expect(response_body).to have_key('errors')
        expect(response_body).to have_key('message')
        expect(response_body['message']).to eq('User creation failed')
        expect(response_body['errors']).to include("Email can't be blank")
      end

      it 'does not create a user when password is missing' do
        expect {
          post '/users', params: { email: 'user@example.com' }
        }.not_to change(User, :count)

        expect(response).to have_http_status(:unprocessable_entity)

        response_body = JSON.parse(response.body)
        expect(response_body).to have_key('errors')
        expect(response_body).to have_key('message')
        expect(response_body['message']).to eq('User creation failed')
        expect(response_body['errors']).to include("Password can't be blank")
      end

      it 'does not create a user when email is empty' do
        expect {
          post '/users', params: invalid_params
        }.not_to change(User, :count)

        expect(response).to have_http_status(:unprocessable_entity)

        response_body = JSON.parse(response.body)
        expect(response_body).to have_key('errors')
        expect(response_body).to have_key('message')
        expect(response_body['message']).to eq('User creation failed')
        expect(response_body['errors']).to include("Email can't be blank")
      end

      it 'does not create a user with duplicate email' do
        # Create a user first
        User.create!(email: 'user@example.com', password: 'password123')

        expect {
          post '/users', params: valid_params
        }.not_to change(User, :count)

        expect(response).to have_http_status(:unprocessable_entity)

        response_body = JSON.parse(response.body)
        expect(response_body).to have_key('errors')
        expect(response_body).to have_key('message')
        expect(response_body['message']).to eq('User creation failed')
        expect(response_body['errors']).to include('Email has already been taken')
      end

      it 'does not create a user with invalid email format' do
        invalid_emails = [
          'plainaddress',           # No @ symbol
          '@missing-local.com',     # Missing local part
          'missing@domain',         # Missing TLD
          'spaces @domain.com'      # Invalid characters
        ]

        invalid_emails.each do |invalid_email|
          expect {
            post '/users', params: { email: invalid_email, password: 'password123' }
          }.not_to change(User, :count)

          expect(response).to have_http_status(:unprocessable_entity)

          response_body = JSON.parse(response.body)
          expect(response_body['errors']).to include('Email must be a valid email address')
        end
      end

      it 'does not create user with case-insensitive duplicate email' do
        # Create a user with lowercase email
        User.create!(email: 'test@example.com', password: 'password123')

        # Try to create another user with uppercase email
        expect {
          post '/users', params: { email: 'TEST@EXAMPLE.COM', password: 'password123' }
        }.not_to change(User, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        response_body = JSON.parse(response.body)
        expect(response_body['errors']).to include('Email has already been taken')
      end
    end

    context 'edge cases' do
      it 'handles special characters in email' do
        special_email = 'user+test@example-domain.co.uk'
        params = { email: special_email, password: 'password123' }

        post '/users', params: params

        expect(response).to have_http_status(:created)
        expect(User.last.email).to eq(special_email)
      end

      it 'handles very long emails' do
        long_email = "#{'a' * 50}@example.com"
        params = { email: long_email, password: 'password123' }

        post '/users', params: params

        expect(response).to have_http_status(:created)
        expect(User.last.email).to eq(long_email)
      end

      it 'handles short password length' do
        params = { email: 'test@example.com', password: 'ab' }

        post '/users', params: params

        # Password validation depends on Rails configuration
        expect(response).to have_http_status(:created).or have_http_status(:unprocessable_entity)

        if response.status == 422
          response_body = JSON.parse(response.body)
          expect(response_body['errors']).to be_present
        end
      end

      it 'handles maximum email length gracefully' do
        very_long_email = "#{'a' * 200}@example.com"
        params = { email: very_long_email, password: 'password123' }

        post '/users', params: params

        # Should either succeed or fail gracefully
        expect(response).to have_http_status(:created).or have_http_status(:unprocessable_entity)
      end
    end

    context 'content type handling' do
      it 'accepts application/json content type' do
        post '/users',
             params: valid_params.to_json,
             headers: { 'CONTENT_TYPE' => 'application/json' }

        expect(response).to have_http_status(:created)
      end

      it 'accepts form-encoded parameters' do
        post '/users', params: valid_params

        expect(response).to have_http_status(:created)
      end
    end

    context 'JWT service integration' do
      it 'handles JWT service errors gracefully' do
        allow(JwtService).to receive(:encode).and_raise(StandardError.new('JWT encoding failed'))

        expect {
          post '/users', params: valid_params
        }.to change(User, :count).by(1)  # User is still created

        expect(response).to have_http_status(:internal_server_error)
        response_body = JSON.parse(response.body)
        expect(response_body['errors']).to include('User creation failed')
        expect(response_body['message']).to eq('Registration failed')
      end
    end
  end
end
