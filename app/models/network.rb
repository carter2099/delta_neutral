# Represents a supported blockchain network (e.g. Ethereum mainnet, Arbitrum).
#
# Deletion is blocked while any {Wallet} is associated with this network.
class Network < ApplicationRecord
  has_many :wallets, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true
  validates :chain_id, presence: true, uniqueness: true
end
