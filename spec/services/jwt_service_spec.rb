require 'rails_helper'

RSpec.describe JwtService do
  let(:payload) { { user_id: '12345', token_version: 0 } }

  describe '.encode and .decode' do
    it 'encodes and decodes a valid token' do
      token = JwtService.encode(payload)
      decoded = JwtService.decode(token)
      expect(decoded[:user_id]).to eq('12345')
      expect(decoded[:token_version]).to eq(0)
    end

    it 'raises error on expired token' do
      token = JwtService.encode(payload, exp: 1.second.ago)
      expect { JwtService.decode(token) }.to raise_error(StandardError, 'Token has expired')
    end

    it 'raises error on invalid token' do
      expect { JwtService.decode('invalid.token.string') }.to raise_error(StandardError, /Invalid token/)
    end
  end
end
