# Represents a user-owned blockchain wallet on a specific {Network}.
#
# A wallet is the entry point for syncing {Position positions} via
# {WalletSyncJob}. Destroying a wallet cascades to all its positions.
class Wallet < ApplicationRecord
  belongs_to :user
  belongs_to :network

  has_many :positions, dependent: :destroy

  validates :address, presence: true
end
