# Updates price data and records P&L snapshots for one or all active positions.
#
# Fetches current pool prices from the Uniswap subgraph and unrealized hedge
# P&L from Hyperliquid, then persists a {PnlSnapshot} for each position.
#
# @example Sync a single position
#   PositionSyncJob.perform_later(position.id)
#
# @example Sync all active positions (used by the recurring scheduler)
#   PositionSyncJob.perform_later
class PositionSyncJob < ApplicationJob
  queue_as :default

  # Performs the position sync.
  #
  # @param position_id [Integer, nil] ID of the position to sync, or +nil+
  #   to sync all active positions
  # @return [void]
  def perform(position_id = nil)
    Rails.logger.debug { "[PositionSyncJob] starting — position_id=#{position_id || 'all active'}" }
    positions = position_id ? Position.where(id: position_id) : Position.active
    uniswap = UniswapService.new
    hyperliquid = HyperliquidService.new

    Rails.logger.debug { "[PositionSyncJob] found #{positions.count} position(s) to sync" }

    positions.includes(:hedge).find_each do |position|
      sync_position(position, uniswap, hyperliquid)
    rescue => e
      Rails.logger.error("PositionSyncJob failed for position #{position.id}: #{e.message}")
    end

    Rails.logger.debug { "[PositionSyncJob] complete" }
  end

  private

  # Syncs prices and creates a {PnlSnapshot} for a single position.
  #
  # Skips the position if no pool data is available from the subgraph.
  # Fetches unrealized hedge P&L from Hyperliquid if an active hedge exists.
  #
  # @param position [Position] the position to sync
  # @param uniswap [UniswapService] configured Uniswap subgraph client
  # @param hyperliquid [HyperliquidService] configured Hyperliquid client
  # @return [void]
  def sync_position(position, uniswap, hyperliquid)
    Rails.logger.debug { "[PositionSyncJob] syncing position #{position.id} (#{position.asset0}/#{position.asset1}, pool=#{position.pool_address})" }
    pool_data = uniswap.fetch_pool_data(position.pool_address)
    unless pool_data
      Rails.logger.warn("PositionSyncJob: skipping position #{position.id} — no pool data returned from subgraph")
      return
    end

    Rails.logger.debug { "[PositionSyncJob] position #{position.id} prices: #{position.asset0} $#{pool_data[:token0_price_usd]&.round(4)}, #{position.asset1} $#{pool_data[:token1_price_usd]&.round(4)}" }

    old_prices = [ position.asset0_price_usd, position.asset1_price_usd ]
    position.update!(
      asset0_price_usd: pool_data[:token0_price_usd],
      asset1_price_usd: pool_data[:token1_price_usd]
    )
    Rails.logger.debug { "[PositionSyncJob] position #{position.id} price update: asset0 #{old_prices[0]} → #{position.asset0_price_usd}, asset1 #{old_prices[1]} → #{position.asset1_price_usd}" }

    if position.entry_value_usd.nil?
      position.update!(entry_value_usd: position.total_value_usd)
      Rails.logger.debug { "[PositionSyncJob] position #{position.id} entry_value_usd set to #{position.entry_value_usd}" }
    end

    hedge_unrealized = BigDecimal("0")
    hedge_realized = BigDecimal("0")

    if position.hedge&.active?
      Rails.logger.debug { "[PositionSyncJob] position #{position.id} has active hedge #{position.hedge.id}, fetching Hyperliquid positions" }
      all_positions = hyperliquid.get_positions
      [ position.asset0, position.asset1 ].each do |asset|
        hl_asset = HyperliquidService.normalize_symbol(asset)
        pos = all_positions.find { |p| p[:asset] == hl_asset }
        if pos
          Rails.logger.debug { "[PositionSyncJob] hedge PnL for #{asset}: unrealized=#{pos[:unrealized_pnl]}" }
          hedge_unrealized += pos[:unrealized_pnl]
        else
          Rails.logger.debug { "[PositionSyncJob] no Hyperliquid position found for #{asset}" }
        end
      end

      hedge_realized = position.hedge.short_rebalances.sum(:realized_pnl)
      Rails.logger.debug { "[PositionSyncJob] position #{position.id} hedge totals: unrealized=#{hedge_unrealized}, realized=#{hedge_realized}" }
    else
      Rails.logger.debug { "[PositionSyncJob] position #{position.id} has no active hedge" }
    end

    pool_unrealized = position.entry_value_usd ? position.total_value_usd - position.entry_value_usd : BigDecimal("0")

    PnlSnapshot.create!(
      position: position,
      captured_at: Time.current,
      asset0_amount: position.asset0_amount,
      asset1_amount: position.asset1_amount,
      asset0_price_usd: position.asset0_price_usd,
      asset1_price_usd: position.asset1_price_usd,
      hedge_unrealized: hedge_unrealized,
      hedge_realized: hedge_realized,
      pool_unrealized: pool_unrealized
    )
    Rails.logger.debug { "[PositionSyncJob] position #{position.id} PnlSnapshot created" }
  end
end
