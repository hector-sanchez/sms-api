class JwtService
  SECRET = ENV['JWT_SECRET']
  ALGORITHM = 'HS256'

  def self.encode(payload, exp: 24.hours.from_now)
    payload[:exp] = exp.to_i
    JWT.encode(payload, SECRET, ALGORITHM)
  end

  def self.decode(token)
    decoded = JWT.decode(token, SECRET, true, { algorithm: ALGORITHM })
    decoded.first.symbolize_keys
  rescue JWT::ExpiredSignature
    raise StandardError, 'Token has expired'
  rescue JWT::DecodeError => e
    raise StandardError, "Invalid token: #{e.message}"
  end
end
