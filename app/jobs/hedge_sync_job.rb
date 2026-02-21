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
# When two hedges share the same HL asset (e.g. two ETH pools), subaccounts
# provide per-hedge isolation. The main account is used first; subsequent
# hedges for the same asset are allocated to subaccounts.
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
    Rails.logger.debug { "[HedgeSyncJob] starting — hedge_id=#{hedge_id || 'all active'}" }
    hedges = hedge_id ? Hedge.where(id: hedge_id) : Hedge.active
    hyperliquid = HyperliquidService.new

    Rails.logger.debug { "[HedgeSyncJob] found #{hedges.count} hedge(s) to sync" }

    hedges.includes(:position).find_each do |hedge|
      sync_hedge(hedge, hyperliquid)
    rescue => e
      Rails.logger.error("HedgeSyncJob failed for hedge #{hedge.id}: #{e.message}")
    end

    Rails.logger.debug { "[HedgeSyncJob] complete" }
  end

  private

  # Checks and rebalances both assets for a hedge, if the position is active.
  #
  # @param hedge [Hedge] the hedge to evaluate
  # @param hyperliquid [HyperliquidService] configured Hyperliquid client
  # @return [void]
  def sync_hedge(hedge, hyperliquid)
    Rails.logger.debug { "[HedgeSyncJob] syncing hedge #{hedge.id} (target=#{hedge.target}, tolerance=#{hedge.tolerance})" }
    position = hedge.position
    unless position.active?
      Rails.logger.warn("HedgeSyncJob: skipping hedge #{hedge.id} — position #{position.id} is inactive")
      return
    end

    Rails.logger.debug { "[HedgeSyncJob] hedge #{hedge.id} position #{position.id} is active, checking assets" }
    check_and_rebalance(hedge, position.asset0, position.asset0_amount, 0, hyperliquid)
    check_and_rebalance(hedge, position.asset1, position.asset1_amount, 1, hyperliquid)
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
  # @param asset_index [Integer] 0 or 1 — which asset in the pair
  # @param hyperliquid [HyperliquidService] configured Hyperliquid client
  # @return [void]
  def check_and_rebalance(hedge, asset, pool_amount, asset_index, hyperliquid)
    hl_asset = HyperliquidService.normalize_symbol(asset)
    account_address = resolve_account(hedge, hl_asset, asset_index, hyperliquid)
    vault_address = account_address # nil for main, subaccount address otherwise

    Rails.logger.debug { "[HedgeSyncJob] hedge #{hedge.id} #{asset} (hl: #{hl_asset}): pool_amount=#{pool_amount}, account=#{account_address || 'main'}" }
    current_position = hyperliquid.get_position(hl_asset, address: account_address)
    current_short = current_position ? current_position[:size].abs : BigDecimal("0")
    decimals = hyperliquid.sz_decimals(hl_asset)
    target_short = (pool_amount * hedge.target).floor(decimals)

    Rails.logger.debug { "[HedgeSyncJob] hedge #{hedge.id} #{asset}: current_short=#{current_short}, target_short=#{target_short}" }

    unless hedge.needs_rebalance?(pool_amount, current_short)
      Rails.logger.debug { "[HedgeSyncJob] hedge #{hedge.id} #{asset}: within tolerance, no rebalance needed" }
      return
    end

    # Skip if the last 3 rebalances for this asset all failed — avoids
    # polluting history with repeated identical failures (e.g. below $10 min).
    # The streak resets naturally when conditions change enough for one to succeed.
    recent = hedge.short_rebalances.where(asset: asset).where(rebalanced_at: 24.hours.ago..).order(rebalanced_at: :desc).limit(3)
    if recent.size == 3 && recent.all? { |r| r.status == ShortRebalance::STATUS_FAILED }
      Rails.logger.debug { "[HedgeSyncJob] hedge #{hedge.id} #{asset}: skipping — last 3 rebalances all failed" }
      return
    end

    Rails.logger.debug { "[HedgeSyncJob] hedge #{hedge.id} #{asset}: REBALANCE NEEDED" }
    realized_pnl = BigDecimal("0")

    begin
      # Close existing short and get realized PnL from fills
      if current_short > 0
        Rails.logger.debug { "[HedgeSyncJob] hedge #{hedge.id} #{asset}: closing existing short (size=#{current_short})" }
        before_close = Time.current
        hyperliquid.close_short(asset: hl_asset, vault_address: vault_address)
        realized_pnl = fetch_realized_pnl(hyperliquid, hl_asset, before_close, address: account_address)
        Rails.logger.debug { "[HedgeSyncJob] hedge #{hedge.id} #{asset}: realized_pnl=#{realized_pnl}" }
      end

      # Open new short at target size (not needed when target or pool amt is 0)
      if target_short > 0
        # Ensure subaccount has sufficient margin before opening
        ensure_subaccount_margin(hyperliquid, account_address, hl_asset, target_short, hedge) if account_address

        setting = hedge.position.user.setting
        leverage = setting&.hyperliquid_leverage || 3
        is_cross = setting&.hyperliquid_cross_margin.nil? ? true : setting.hyperliquid_cross_margin
        Rails.logger.debug { "[HedgeSyncJob] hedge #{hedge.id} #{asset}: setting leverage=#{leverage}, is_cross=#{is_cross}" }
        hyperliquid.set_leverage(asset: hl_asset, leverage: leverage, is_cross: is_cross, vault_address: vault_address)
        Rails.logger.debug { "[HedgeSyncJob] hedge #{hedge.id} #{asset}: opening new short (size=#{target_short})" }
        hyperliquid.open_short(asset: hl_asset, size: target_short, vault_address: vault_address)
      else
        Rails.logger.debug { "[HedgeSyncJob] hedge #{hedge.id} #{asset}: target is zero, skipping open" }

        # Withdraw USDC back to main when closing to zero on a subaccount
        if account_address
          withdraw_subaccount_balance(hyperliquid, account_address)
          hl_col = asset_index == 0 ? :asset0_hl_account : :asset1_hl_account
          hedge.update!(hl_col => nil)
          Rails.logger.debug { "[HedgeSyncJob] hedge #{hedge.id} #{asset}: cleared subaccount assignment" }
        end
      end

      rebalance = hedge.short_rebalances.create!(
        asset: asset,
        old_short_size: current_short,
        new_short_size: target_short,
        realized_pnl: realized_pnl,
        status: ShortRebalance::STATUS_SUCCESS,
        rebalanced_at: Time.current
      )
      Rails.logger.debug { "[HedgeSyncJob] hedge #{hedge.id} #{asset}: ShortRebalance ##{rebalance.id} created (#{current_short} → #{target_short}, realized_pnl=#{realized_pnl})" }

      HedgeRebalanceMailer.rebalance_notification(rebalance).deliver_later
    rescue => e
      # Close succeeded but open failed — short is now 0; if close also failed, size unchanged
      new_short_size = current_short > 0 && defined?(before_close) ? BigDecimal("0") : current_short

      rebalance = hedge.short_rebalances.create!(
        asset: asset,
        old_short_size: current_short,
        new_short_size: new_short_size,
        realized_pnl: realized_pnl,
        status: ShortRebalance::STATUS_FAILED,
        message: "Attempted to open short of #{target_short} #{hl_asset}: #{e.message}",
        rebalanced_at: Time.current
      )
      Rails.logger.error("[HedgeSyncJob] hedge #{hedge.id} #{asset}: rebalance failed — ShortRebalance ##{rebalance.id}: #{e.message}")

      raise
    end
  end

  # Resolves which HL account (main or subaccount) to use for this hedge+asset.
  #
  # If an account is already assigned, returns it. Otherwise, checks if the
  # main account is free for this asset, and if not, finds or creates a subaccount.
  #
  # @param hedge [Hedge] the hedge
  # @param hl_asset [String] the HL trading symbol
  # @param asset_index [Integer] 0 or 1
  # @param hyperliquid [HyperliquidService] configured Hyperliquid client
  # @return [String, nil] subaccount address, or +nil+ for main account
  def resolve_account(hedge, hl_asset, asset_index, hyperliquid)
    existing = hedge.hl_account_for(asset_index)
    return existing if existing

    # Main account is free for this asset — use it (leave column nil)
    return nil unless Hedge.asset_account_in_use?(hl_asset, exclude_hedge: hedge)

    # Main is taken — find an available subaccount
    subaccounts = hyperliquid.list_subaccounts
    available = subaccounts.find do |sa|
      addr = sa["subAccountUser"]
      !Hedge.subaccount_in_use_for?(addr, hl_asset)
    end

    address = if available
      available["subAccountUser"]
    else
      result = hyperliquid.create_subaccount(name: "hedge-#{hedge.id}-#{hl_asset.downcase}")
      result["subAccountUser"]
    end

    # Persist the assignment
    hl_col = asset_index == 0 ? :asset0_hl_account : :asset1_hl_account
    hedge.update!(hl_col => address)
    Rails.logger.debug { "[HedgeSyncJob] hedge #{hedge.id}: assigned #{hl_asset} to subaccount #{address}" }
    address
  end

  # Ensures a subaccount has enough margin for the target short.
  #
  # Calculates the required margin with a 20% buffer, checks the existing
  # balance, and only transfers the difference.
  #
  # @param hyperliquid [HyperliquidService]
  # @param account_address [String] the subaccount address
  # @param hl_asset [String] the asset symbol
  # @param target_short [BigDecimal] the target short size
  # @param hedge [Hedge] the parent hedge (for leverage lookup)
  # @return [void]
  def ensure_subaccount_margin(hyperliquid, account_address, hl_asset, target_short, hedge)
    mark_price = hyperliquid.get_position(hl_asset, address: account_address)&.dig(:mark_price)
    mark_price ||= hyperliquid.get_positions.find { |p| p[:asset] == hl_asset }&.dig(:mark_price)
    return unless mark_price && mark_price > 0

    setting = hedge.position.user.setting
    leverage = setting&.hyperliquid_leverage || 3
    margin_needed = (target_short * mark_price / leverage * BigDecimal("1.2")).ceil(2)

    balance = hyperliquid.account_balance(account_address)
    existing = balance[:account_value]
    transfer_amount = margin_needed - existing

    if transfer_amount > 0
      Rails.logger.debug { "[HedgeSyncJob] transferring #{transfer_amount} USDC to subaccount #{account_address} (needed=#{margin_needed}, existing=#{existing})" }
      hyperliquid.transfer_to_subaccount(subaccount_address: account_address, usd: transfer_amount)
    end
  end

  # Withdraws all USDC from a subaccount back to the main account.
  #
  # @param hyperliquid [HyperliquidService]
  # @param account_address [String] the subaccount address
  # @return [void]
  def withdraw_subaccount_balance(hyperliquid, account_address)
    balance = hyperliquid.account_balance(account_address)
    withdrawable = balance[:withdrawable]
    if withdrawable > 0
      Rails.logger.debug { "[HedgeSyncJob] withdrawing #{withdrawable} USDC from subaccount #{account_address}" }
      hyperliquid.withdraw_from_subaccount(subaccount_address: account_address, usd: withdrawable)
    end
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
  # @param address [String, nil] wallet/subaccount address for fills query
  # @return [BigDecimal] total realized P&L, or +0+ on error
  def fetch_realized_pnl(hyperliquid, asset, since, address: nil)
    fills = hyperliquid.user_fills(start_time: since, address: address)
    fills
      .select { |f| f["coin"] == asset && f["closedPnl"].present? }
      .sum { |f| BigDecimal(f["closedPnl"]) }
  rescue => e
    Rails.logger.warn("Failed to fetch realized PnL from fills for #{asset}: #{e.message}")
    BigDecimal("0")
  end
end
