class Message
  include Mongoid::Document
  include Mongoid::Timestamps

  field :body, type: String
  field :to, type: String
  field :status, type: String, default: 'pending'
  field :twilio_sid, type: String

  belongs_to :user

  # Validations
  validates :body, presence: true, length: { maximum: 1600 }
  validates :to, presence: true, format: {
    with: /\A\+[1-9]\d{8,14}\z/,
    message: "must be a valid phone number"
  }
  validates :status, inclusion: {
    in: %w[pending queued sent delivered failed],
    message: "must be a valid status"
  }
  validates :user, presence: true

  # Scopes
  scope :successful, -> { where(status: %w[queued sent delivered]) }
  scope :failed, -> { where(status: 'failed') }
  scope :pending, -> { where(status: 'pending') }
  scope :recent, -> { order(created_at: :desc) }

  # Instance methods
  def successful?
    %w[queued sent delivered].include?(status)
  end

  def failed?
    status == 'failed'
  end

  def pending?
    status == 'pending'
  end

  def delivered?
    status == 'delivered'
  end
end
