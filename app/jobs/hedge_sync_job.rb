class HedgeSyncJob < ApplicationJob
  queue_as :default

  def perform(position_id)
    position = Position.find(position_id)
    user = position.user

    client = Hyperliquid::ClientWrapper.new(testnet: user.testnet?)
    hl_positions = client.positions

    # Get the assets we care about for this position
    config = position.hedge_configuration
    return unless config

    relevant_assets = []
    relevant_assets << config.mapping_for(position.token0_symbol) if config.should_hedge?(position.token0_symbol)
    relevant_assets << config.mapping_for(position.token1_symbol) if config.should_hedge?(position.token1_symbol)
    relevant_assets.compact!

    # Update or create hedge positions for relevant assets
    relevant_assets.each do |asset|
      hl_pos = hl_positions.find { |p| p[:asset] == asset }

      hedge = position.hedge_positions.find_or_initialize_by(asset: asset)

      if hl_pos && hl_pos[:size] != 0
        hedge.update!(
          size: hl_pos[:size],
          entry_price: hl_pos[:entry_price],
          current_price: client.market_price(asset),
          unrealized_pnl: hl_pos[:unrealized_pnl],
          liquidation_price: hl_pos[:liquidation_price],
          margin_used: hl_pos[:margin_used],
          last_synced_at: Time.current
        )
      elsif hedge.persisted?
        # Position was closed
        hedge.update!(
          size: 0,
          unrealized_pnl: 0,
          last_synced_at: Time.current
        )
      end
    end

    Rails.logger.info "[HedgeSyncJob] Synced hedge positions for position #{position_id}"
  rescue Hyperliquid::ClientWrapper::Error => e
    Rails.logger.error "[HedgeSyncJob] Error syncing hedges for position #{position_id}: #{e.message}"
    raise
  end
end
