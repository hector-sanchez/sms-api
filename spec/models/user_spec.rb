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
