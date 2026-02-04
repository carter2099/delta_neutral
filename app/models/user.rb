class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :positions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :wallet_address, with: ->(w) { w&.strip&.downcase }

  validates :email_address, presence: true, uniqueness: true
  validates :wallet_address, format: { with: /\A0x[a-fA-F0-9]{40}\z/, allow_blank: true }

  def paper_trading?
    paper_trading_mode?
  end

  def testnet?
    testnet_mode?
  end
end
