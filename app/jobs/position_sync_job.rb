class PositionSyncJob < ApplicationJob
  queue_as :default

  def perform(position_id)
    position = Position.find(position_id)
    return unless position.active?

    fetcher = Subgraph::PositionFetcher.new(network: position.network)
    data = fetcher.fetch(position.nft_id)

    # Calculate token amounts using liquidity math
    amounts = Uniswap::LiquidityMath.get_amounts(
      liquidity: data[:liquidity],
      current_tick: data[:pool][:tick],
      tick_lower: data[:tick_lower],
      tick_upper: data[:tick_upper],
      token0_decimals: data[:token0][:decimals],
      token1_decimals: data[:token1][:decimals]
    )

    # Fetch price data
    pool_data = fetcher.fetch_pool(data[:pool][:id])

    position.update!(
      pool_address: data[:pool][:id],
      token0_address: data[:token0][:address],
      token1_address: data[:token1][:address],
      token0_symbol: data[:token0][:symbol],
      token1_symbol: data[:token1][:symbol],
      token0_decimals: data[:token0][:decimals],
      token1_decimals: data[:token1][:decimals],
      tick_lower: data[:tick_lower],
      tick_upper: data[:tick_upper],
      liquidity: data[:liquidity],
      current_tick: data[:pool][:tick],
      token0_amount: amounts[:token0],
      token1_amount: amounts[:token1],
      token0_price_usd: pool_data&.dig(:token0, :price_usd),
      token1_price_usd: pool_data&.dig(:token1, :price_usd),
      last_synced_at: Time.current
    )

    # Set initial values if not yet set
    if position.initial_token0_value_usd.nil? && pool_data
      position.update!(
        initial_token0_value_usd: amounts[:token0] * (pool_data.dig(:token0, :price_usd) || 0),
        initial_token1_value_usd: amounts[:token1] * (pool_data.dig(:token1, :price_usd) || 0)
      )
    end

    # Trigger hedge analysis after sync
    HedgeAnalysisJob.perform_later(position_id)

    Rails.logger.info "[PositionSyncJob] Synced position #{position_id}: #{amounts[:token0]} #{data[:token0][:symbol]}, #{amounts[:token1]} #{data[:token1][:symbol]}"
  rescue Subgraph::PositionFetcher::PositionNotFound => e
    Rails.logger.warn "[PositionSyncJob] Position not found: #{e.message}"
    position.update!(active: false) if position
  rescue => e
    Rails.logger.error "[PositionSyncJob] Error syncing position #{position_id}: #{e.message}"
    raise
  end
end
