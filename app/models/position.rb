# Represents a liquidity pool position held in a user's {Wallet}.
#
# A position tracks two assets (+asset0+ / +asset1+), their current amounts,
# and their USD prices as fetched from the Uniswap subgraph. Positions may
# optionally have a {Hedge} for delta-neutral management.
class Position < ApplicationRecord
  belongs_to :user
  belongs_to :dex
  belongs_to :wallet

  has_one :hedge, dependent: :destroy
  has_many :pnl_snapshots, dependent: :destroy

  # @!scope class
  # @!method active
  #   Returns only positions that are currently active.
  #   @return [ActiveRecord::Relation<Position>]
  scope :active, -> { where(active: true) }

  # Calculates the total USD value of both assets in this position.
  #
  # Treats +nil+ amounts or prices as zero.
  #
  # @return [BigDecimal] the sum of (asset0_amount * asset0_price_usd) and
  #   (asset1_amount * asset1_price_usd)
  def total_value_usd
    ((asset0_amount || 0) * (asset0_price_usd || 0)) + ((asset1_amount || 0) * (asset1_price_usd || 0))
  end
end
