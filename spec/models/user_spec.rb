require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'fields' do
    it { is_expected.to have_field(:email).of_type(String) }
    it { is_expected.to have_field(:password_digest).of_type(String) }
    it { is_expected.to have_field(:token_version).of_type(Integer) }
  end

  describe 'validations' do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email) }

    # Test password validation through has_secure_password behavior
    it 'validates presence of password on creation' do
      user = build(:user, password: nil)
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("can't be blank")
    end

    describe 'email format validation' do
      it 'accepts valid email addresses' do
        valid_emails = [
          'user@example.com',
          'test.email@domain.co.uk',
          'user+tag@example.org',
          'firstname.lastname@company.com',
          'user123@test-domain.com'
        ]

        valid_emails.each do |email|
          user = build(:user, email: email)
          expect(user).to be_valid, "Expected #{email} to be valid"
        end
      end

      it 'rejects invalid email addresses' do
        invalid_emails = [
          'plainaddress',           # No @ symbol
          '@missingdomain.com',     # Missing local part
          'missing@domain',         # Missing TLD
          'spaces @domain.com',     # Spaces in local part
          'user@',                  # Missing domain
          'user@domain.',            # Invalid domain ending
          'user@domain..com'            # Invalid domain ending
        ]

        invalid_emails.each do |email|
          user = build(:user, email: email)
          expect(user).not_to be_valid, "Expected #{email} to be invalid"
          expect(user.errors[:email]).to include("must be a valid email address")
        end
      end

      it 'validates case-insensitive uniqueness' do
        User.create!(email: 'test@example.com', password: 'password123')

        user = build(:user, email: 'TEST@EXAMPLE.COM')
        expect(user).not_to be_valid
        expect(user.errors[:email]).to include('has already been taken')
      end
    end

    describe 'email normalization' do
      it 'converts email to lowercase before saving' do
        user = create(:user, email: 'TEST@EXAMPLE.COM')
        expect(user.email).to eq('test@example.com')
      end

      it 'strips whitespace from email before saving' do
        user = create(:user, email: '  test@example.com  ')
        expect(user.email).to eq('test@example.com')
      end

      it 'handles mixed case and whitespace' do
        user = create(:user, email: '  TEST@Example.COM  ')
        expect(user.email).to eq('test@example.com')
      end
    end
  end

  describe 'associations' do
    it { is_expected.to have_many(:messages) }
  end

  describe 'secure password' do
    let(:user) { build(:user, password: 'password123') }

    it 'encrypts password' do
      expect(user.password_digest).to be_present
    end

    it 'authenticates with correct password' do
      user.save!
      expect(user.authenticate('password123')).to eq(user)
    end

    it 'does not authenticate with incorrect password' do
      user.save!
      expect(user.authenticate('wrong_password')).to be_falsey
    end
  end

  describe 'timestamps' do
    it { is_expected.to have_field(:created_at) }
    it { is_expected.to have_field(:updated_at) }
  end
end
