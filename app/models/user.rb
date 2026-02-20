# Represents an authenticated user of the application.
#
# Passwords are stored as bcrypt digests via +has_secure_password+.
# Email addresses are normalized to stripped lowercase on assignment.
class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :wallets, dependent: :destroy
  has_many :positions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :first_name, :last_name, presence: true
end
