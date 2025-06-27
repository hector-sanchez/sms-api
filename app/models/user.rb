class User
  include Mongoid::Document
  include Mongoid::Timestamps
  include ActiveModel::SecurePassword

  field :email, type: String
  field :password_digest, type: String
  field :token_version, type: Integer

  has_secure_password

  validates :email, presence: true, uniqueness: true
  has_many :messages
end
