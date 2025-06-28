# SMS API

A Rails API for sending SMS messages via Twilio with JWT authentication.

## Features

- 📱 Send SMS messages via Twilio
- 🔐 JWT-based authentication with token versioning
- 👤 User registration and authentication
- 📋 Message history retrieval
- ✅ Comprehensive input validation
- 🌍 International phone number support
- 🧪 Full test coverage with RSpec

## System Requirements

* Ruby 3.4.4
* Rails 8.0.2
* MongoDB (via Mongoid)
* Twilio Account

## Configuration

### Environment Variables

Create a `.env` file with the following variables:

```bash
JWT_SECRET=your_jwt_secret_key_here
TWILIO_ACCOUNT_SID=your_twilio_account_sid
TWILIO_AUTH_TOKEN=your_twilio_auth_token
TWILIO_PHONE_NUMBER=your_twilio_phone_number
```

### Database

This application uses MongoDB. Make sure MongoDB is running and configure your connection in `config/mongoid.yml`.

## Installation

1. Clone the repository
2. Install dependencies: `bundle install`
3. Set up environment variables (see Configuration section)
4. Start the server: `rails server`

## API Endpoints

### Authentication

#### Register User
```bash
# Create a new user account
curl -X POST http://localhost:3000/users \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "password123"
  }'
```

**Response:**
```json
{
  "user": {
    "id": "507f1f77bcf86cd799439011",
    "email": "user@example.com",
    "token_version": 1
  },
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "message": "User created successfully"
}
```

#### Login
```bash
# Authenticate and get JWT token
curl -X POST http://localhost:3000/auths \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "password123"
  }'
```

**Response:**
```json
{
  "user": {
    "id": "507f1f77bcf86cd799439011",
    "email": "user@example.com",
    "token_version": 1
  },
  "token": "eyJhbGciOiJIUzI1NiJ9...",
  "message": "Authentication successful"
}
```

#### Logout
```bash
# Invalidate current token
curl -X DELETE http://localhost:3000/auths \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Response:**
```json
{
  "message": "Logout successful"
}
```

### SMS Messages

#### Send SMS
```bash
# Send an SMS message
curl -X POST http://localhost:3000/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "to": "+1234567890",
    "body": "Hello from SMS API!"
  }'
```

**Response (Success):**
```json
{
  "message": {
    "id": "507f1f77bcf86cd799439012",
    "body": "Hello from SMS API!",
    "to": "+1234567890",
    "status": "queued",
    "twilio_sid": "SM1234567890abcdef",
    "created_at": "2025-06-28T10:30:00.000Z",
    "updated_at": "2025-06-28T10:30:00.000Z"
  },
  "status": "success",
  "message_text": "Message processed successfully"
}
```

#### Get User Messages
```bash
# Retrieve message history for authenticated user
curl -X GET http://localhost:3000/users/USER_ID/messages \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Response:**
```json
{
  "messages": [
    {
      "id": "507f1f77bcf86cd799439012",
      "body": "Hello from SMS API!",
      "to": "+1234567890",
      "status": "delivered",
      "created_at": "2025-06-28T10:30:00.000Z",
      "updated_at": "2025-06-28T10:30:00.000Z"
    }
  ],
  "count": 1,
  "status": "success",
  "message_text": "Messages retrieved successfully"
}
```

## Error Responses

### Validation Errors
```json
{
  "errors": ["To must be a valid phone number"],
  "status": "error",
  "message_text": "Validation failed"
}
```

### Authentication Errors
```json
{
  "error": "Invalid email or password",
  "message": "Authentication failed"
}
```

### Authorization Errors
```json
{
  "error": "Unauthorized"
}
```

## Phone Number Format

Phone numbers must be in E.164 format:
- ✅ `+1234567890` (US)
- ✅ `+447911123456` (UK)
- ✅ `+52123456789` (Mexico)
- ❌ `123-456-7890`
- ❌ `(123) 456-7890`

## Message Limits

- Maximum message body length: 1,600 characters
- Messages exceeding this limit will be rejected

## Testing

Run the test suite:
```bash
# Run all tests
bundle exec rspec

# Run specific test files
bundle exec rspec spec/requests/messages_spec.rb
bundle exec rspec spec/services/twilio_service_spec.rb
```

## Example Workflow

1. **Register a user:**
```bash
curl -X POST http://localhost:3000/users \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "password": "password123"}'
```

2. **Login to get token:**
```bash
curl -X POST http://localhost:3000/auths \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "password": "password123"}'
```

3. **Send SMS (replace TOKEN and USER_ID):**
```bash
curl -X POST http://localhost:3000/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer TOKEN" \
  -d '{"to": "+1234567890", "body": "Hello World!"}'
```

4. **Check message history:**
```bash
curl -X GET http://localhost:3000/users/USER_ID/messages \
  -H "Authorization: Bearer TOKEN"
```

## Development

Start the development server:
```bash
rails server
```

The API will be available at `http://localhost:3000`

## Production Deployment

1. Set production environment variables
2. Configure MongoDB connection for production
3. Set up SSL/TLS certificates
4. Deploy using your preferred platform (Heroku, AWS, etc.)

**Important:** Never commit sensitive credentials to version control. Always use environment variables for configuration.
