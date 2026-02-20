# Represents a decentralized exchange (DEX) used to source liquidity positions.
#
# Deletion is blocked while any {Position} references this DEX.
class Dex < ApplicationRecord
  has_many :positions, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true
end
