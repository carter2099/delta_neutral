# Checks active hedges against current pool sizes and rebalances as needed.
#
# For each asset in a position, the job compares the current Hyperliquid
# short against the target derived from +hedge.target+. If the deviation
# exceeds +hedge.tolerance+, it closes the existing short, opens a new one
# at the target size, records a {ShortRebalance}, and sends a notification
# email via {HedgeRebalanceMailer}.
#
# The two assets in a position are managed independently. When a pool asset
# drops to zero (position fully out of range on that side), the target short
# for that asset is also zero, so the rebalance logic closes the over-hedged
# short automatically. The hedge remains active so the sibling asset's short
# continues to be managed, and the zero asset's short is re-opened if the
# position re-enters range on a future sync.
#
# @example Sync a single hedge
#   HedgeSyncJob.perform_later(hedge.id)
#
# @example Sync all active hedges (used by the recurring scheduler)
#   HedgeSyncJob.perform_later
class HedgeSyncJob < ApplicationJob
  queue_as :default

  # Performs the hedge sync.
  #
  # @param hedge_id [Integer, nil] ID of the hedge to sync, or +nil+ to
  #   sync all active hedges
  # @return [void]
  def perform(hedge_id = nil)
    hedges = hedge_id ? Hedge.where(id: hedge_id) : Hedge.active
    hyperliquid = HyperliquidService.new

    hedges.includes(:position).find_each do |hedge|
      sync_hedge(hedge, hyperliquid)
    rescue => e
      Rails.logger.error("HedgeSyncJob failed for hedge #{hedge.id}: #{e.message}")
    end
  end

  private

  # Checks and rebalances both assets for a hedge, if the position is active.
  #
  # @param hedge [Hedge] the hedge to evaluate
  # @param hyperliquid [HyperliquidService] configured Hyperliquid client
  # @return [void]
  def sync_hedge(hedge, hyperliquid)
    position = hedge.position
    unless position.active?
      Rails.logger.warn("HedgeSyncJob: skipping hedge #{hedge.id} — position #{position.id} is inactive")
      return
    end

    check_and_rebalance(hedge, position.asset0, position.asset0_amount, hyperliquid)
    check_and_rebalance(hedge, position.asset1, position.asset1_amount, hyperliquid)
  end

  # Rebalances the short for a single asset if needed.
  #
  # When +pool_amount+ is zero the target short is also zero, so
  # {Hedge#needs_rebalance?} will return +true+ if any short is currently
  # open (the position is over-hedged on that asset). The short is closed,
  # no new short is opened, and the owner is notified. On subsequent syncs
  # the short stays at zero while the pool amount remains zero. If the asset
  # re-enters range (+pool_amount+ becomes positive again), the deviation
  # from zero triggers a normal rebalance that reopens the short.
  #
  # @param hedge [Hedge] the parent hedge
  # @param asset [String] the asset symbol (e.g. +"ETH"+)
  # @param pool_amount [BigDecimal] current token amount in the liquidity pool
  # @param hyperliquid [HyperliquidService] configured Hyperliquid client
  # @return [void]
  def check_and_rebalance(hedge, asset, pool_amount, hyperliquid)
    current_position = hyperliquid.get_position(asset)
    current_short = current_position ? current_position[:size].abs : BigDecimal("0")

    unless hedge.needs_rebalance?(pool_amount, current_short)
      Rails.logger.debug("HedgeSyncJob: hedge #{hedge.id} #{asset} within tolerance, no rebalance needed")
      return
    end

    target_short = pool_amount * hedge.target
    realized_pnl = BigDecimal("0")

    # Close existing short and get realized PnL from fills
    if current_short > 0
      before_close = Time.current
      hyperliquid.close_short(asset: asset)
      realized_pnl = fetch_realized_pnl(hyperliquid, asset, before_close)
    end

    # Open new short at target size (not needed when target or pool amt is 0)
    hyperliquid.open_short(asset: asset, size: target_short) if target_short > 0

    rebalance = hedge.short_rebalances.create!(
      asset: asset,
      old_short_size: current_short,
      new_short_size: target_short,
      realized_pnl: realized_pnl,
      rebalanced_at: Time.current
    )

    HedgeRebalanceMailer.rebalance_notification(rebalance).deliver_later
  end

  # Fetches the realized P&L for an asset from Hyperliquid fill data.
  #
  # Sums the +closedPnl+ field from fills that match the given asset and
  # occurred after the specified timestamp. Returns zero and logs a warning
  # on error.
  #
  # @param hyperliquid [HyperliquidService] configured Hyperliquid client
  # @param asset [String] the asset symbol to filter fills by
  # @param since [Time] only consider fills at or after this time
  # @return [BigDecimal] total realized P&L, or +0+ on error
  def fetch_realized_pnl(hyperliquid, asset, since)
    fills = hyperliquid.user_fills(start_time: since)
    fills
      .select { |f| f["coin"] == asset && f["closedPnl"].present? }
      .sum { |f| BigDecimal(f["closedPnl"]) }
  rescue => e
    Rails.logger.warn("Failed to fetch realized PnL from fills for #{asset}: #{e.message}")
    BigDecimal("0")
  end
end
