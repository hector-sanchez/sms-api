class User
  include Mongoid::Document
  include Mongoid::Timestamps
  include ActiveModel::SecurePassword

  field :email, type: String
  field :password_digest, type: String
  field :token_version, type: Integer, default: 1

  has_secure_password

  validates :email, presence: true, uniqueness: true
  has_many :messages

  # Ensure token_version is set before saving
  before_save :ensure_token_version

  private

  def ensure_token_version
    self.token_version ||= 1
  end
end
