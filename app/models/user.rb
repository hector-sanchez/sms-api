class User
  include Mongoid::Document
  include Mongoid::Timestamps
  include ActiveModel::SecurePassword

  field :email, type: String
  field :password_digest, type: String
  field :token_version, type: Integer, default: 1

  has_secure_password

  validates :email, presence: true, 
                    uniqueness: { case_sensitive: false },
                    format: { 
                      with: /\A[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\z/,
                      message: "must be a valid email address" 
                    }
  has_many :messages

  # Normalize email before validation
  before_validation :normalize_email
  # Ensure token_version is set before saving
  before_save :ensure_token_version

  private

  def ensure_token_version
    self.token_version ||= 1
  end

  def normalize_email
    self.email = email.strip.downcase if email.present?
  end
end
