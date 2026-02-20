# Captures a point-in-time snapshot of a {Position}'s P&L.
#
# Snapshots are created by {PositionSyncJob} and used to track portfolio
# performance over time. Each snapshot records asset amounts, USD prices,
# unrealized hedge P&L from Hyperliquid, and cumulative realized P&L from
# past {ShortRebalance rebalances}.
class PnlSnapshot < ApplicationRecord
  belongs_to :position

  # Calculates the total USD value of both assets recorded in this snapshot.
  #
  # Treats +nil+ amounts or prices as zero.
  #
  # @return [BigDecimal] the sum of (asset0_amount * asset0_price_usd) and
  #   (asset1_amount * asset1_price_usd)
  def total_value_usd
    ((asset0_amount || 0) * (asset0_price_usd || 0)) + ((asset1_amount || 0) * (asset1_price_usd || 0))
  end
end
