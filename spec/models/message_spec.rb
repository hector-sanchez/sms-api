require 'rails_helper'

RSpec.describe Message, type: :model do
  describe 'Mongoid configuration' do
    it 'includes Mongoid::Document' do
      expect(Message.included_modules).to include(Mongoid::Document)
    end

    it 'includes Mongoid::Timestamps' do
      expect(Message.included_modules).to include(Mongoid::Timestamps)
    end
  end

  describe 'fields' do
    it 'has a body field of type String' do
      expect(Message.fields['body'].type).to eq(String)
    end

    it 'has a to field of type String' do
      expect(Message.fields['to'].type).to eq(String)
    end

    it 'has timestamp fields' do
      expect(Message.fields.keys).to include('created_at', 'updated_at')
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:user) }

    it 'requires a user association' do
      message = build(:message, user: nil)
      expect(message).not_to be_valid
      expect(message.errors[:user]).to include("can't be blank")
    end
  end

  describe 'factory' do
    it 'has a valid factory' do
      message = build(:message)
      expect(message).to be_valid
    end

    it 'creates a message with default attributes' do
      message = create(:message)
      expect(message.body).to eq("Hello, this is a test message!")
      expect(message.to).to match(/\+1234567890\d{2}/)
      expect(message.user).to be_present
    end

    it 'creates unique phone numbers for different messages' do
      message1 = create(:message)
      message2 = create(:message)
      expect(message1.to).not_to eq(message2.to)
    end
  end

  describe 'message variance' do
    describe 'long_message' do
      it 'creates a message with a long body' do
        message = create(:message, :long_message)
        expect(message.body.length).to be > 100
        expect(message.body).to include("This is a very long message")
      end
    end

    describe 'short_message' do
      it 'creates a message with a short body' do
        message = create(:message, :short_message)
        expect(message.body).to eq("Hi!")
        expect(message.body.length).to be < 10
      end
    end

    describe 'with_emoji' do
      it 'creates a message with emoji characters' do
        message = create(:message, :with_emoji)
        expect(message.body).to include("😊")
        expect(message.body).to include("🎉")
      end
    end
  end

  describe 'creation and persistence' do
    it 'can be created with valid attributes' do
      user = create(:user)
      message = Message.new(
        body: "Test message",
        to: "+1234567890",
        user: user
      )
      expect(message).to be_valid
      expect { message.save! }.not_to raise_error
    end

    it 'sets timestamps on creation' do
      message = create(:message)
      expect(message.created_at).to be_present
      expect(message.updated_at).to be_present
      expect(message.created_at).to be_within(1.second).of(Time.current)
    end

    it 'updates updated_at when modified' do
      message = create(:message)
      original_updated_at = message.updated_at
      sleep(0.01)
      message.update!(body: "Updated message")
      expect(message.updated_at).to be > original_updated_at
    end
  end

  describe 'user association behavior' do
    it 'can access user through association' do
      user = create(:user)
      message = create(:message, user: user)
      expect(message.user).to eq(user)
      expect(message.user.email).to eq(user.email)
    end

    it 'is included in user messages collection' do
      user = create(:user)
      message = create(:message, user: user)
      expect(user.messages).to include(message)
    end

    it 'multiple messages can belong to same user' do
      user = create(:user)
      message1 = create(:message, user: user)
      message2 = create(:message, user: user)

      expect(user.messages.count).to eq(2)
      expect(user.messages).to include(message1, message2)
    end
  end

  describe 'data validation and edge cases' do
    it 'rejects empty body' do
      message = build(:message, body: "")
      expect(message).not_to be_valid
      expect(message.errors[:body]).to include("can't be blank")
    end

    it 'rejects nil body' do
      message = build(:message, body: nil)
      expect(message).not_to be_valid
      expect(message.errors[:body]).to include("can't be blank")
    end

    it 'rejects empty to field' do
      message = build(:message, to: "")
      expect(message).not_to be_valid
      expect(message.errors[:to]).to include("can't be blank")
    end

    it 'rejects nil to field' do
      message = build(:message, to: nil)
      expect(message).not_to be_valid
      expect(message.errors[:to]).to include("can't be blank")
    end

    it 'rejects message body that is too long' do
      long_body = 'A' * 1601
      message = build(:message, body: long_body)
      expect(message).not_to be_valid
      expect(message.errors[:body]).to include("is too long (maximum is 1600 characters)")
    end

    it 'accepts message body at maximum length' do
      max_length_body = 'A' * 1600
      message = build(:message, body: max_length_body)
      expect(message).to be_valid
    end

    it 'handles special characters in body' do
      special_body = "Test with special chars: !@#$%^&*()_+{}|:<>?[]\\;'\",./"
      message = create(:message, body: special_body)
      expect(message.body).to eq(special_body)
    end

    it 'handles valid international phone numbers' do
      valid_numbers = ["+1234567890", "+447911123456", "+819012345678", "+5511999999999"]
      valid_numbers.each do |number|
        message = build(:message, to: number)
        expect(message).to be_valid, "Expected #{number} to be valid"
      end
    end

    it 'rejects invalid phone number formats' do
      invalid_numbers = ["123-456-7890", "invalid", "+", "123", "", "+123", "1234567890"]
      invalid_numbers.each do |number|
        message = build(:message, to: number)
        expect(message).not_to be_valid, "Expected #{number} to be invalid"
        expect(message.errors[:to]).to include("must be a valid phone number")
      end
    end
  end

  describe 'querying and scopes' do
    before do
      @user1 ||= create(:user)
      @user2 ||= create(:user)
      @message1 ||= create(:message, user: @user1, body: "Hello from user 1")
      @message2 ||= create(:message, user: @user2, body: "Hello from user 2")
      @message3 ||= create(:message, user: @user1, body: "Another message from user 1")
    end

    it 'can find messages by user' do
      user1_messages = Message.where(user: @user1)
      expect(user1_messages.count).to eq(2)
      expect(user1_messages).to include(@message1, @message3)
    end

    it 'can find messages by body content' do
      messages_with_hello = Message.where(body: /Hello/)
      expect(messages_with_hello.count).to eq(2)
      expect(messages_with_hello).to include(@message1, @message2)
    end

    it 'can find messages by phone number' do
      phone_number = @message1.to
      messages_to_number = Message.where(to: phone_number)
      expect(messages_to_number.count).to eq(1)
      expect(messages_to_number.first).to eq(@message1)
    end

    it 'can order messages by creation date' do
      messages = Message.order_by(created_at: :desc)
      expect(messages.first.created_at).to be >= messages.last.created_at
    end
  end

  describe 'performance and memory' do
    it 'can handle creating many messages without memory issues' do
      expect {
        create_list(:message, 100)
      }.not_to raise_error

      expect(Message.count).to eq(100)
    end
  end
end
