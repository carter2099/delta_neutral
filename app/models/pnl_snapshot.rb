# Captures a point-in-time snapshot of a {Position}'s P&L.
#
# Snapshots are created by {PositionSyncJob} and used to track portfolio
# performance over time. Each snapshot records asset amounts, USD prices,
# unrealized hedge P&L from Hyperliquid, and cumulative realized P&L from
# past {ShortRebalance rebalances}.
class PnlSnapshot < ApplicationRecord
  belongs_to :position

  # @return [BigDecimal] total collected + uncollected fees in USD
  def total_fees_usd
    collected_fees_usd + uncollected_fees_usd
  end

  # @return [BigDecimal] cumulative collected fees in USD
  def collected_fees_usd
    ((collected_fees0 || 0) * (asset0_price_usd || 0)) +
      ((collected_fees1 || 0) * (asset1_price_usd || 0))
  end

  # @return [BigDecimal] pending uncollected fees in USD
  def uncollected_fees_usd
    ((uncollected_fees0 || 0) * (asset0_price_usd || 0)) +
      ((uncollected_fees1 || 0) * (asset1_price_usd || 0))
  end
end
