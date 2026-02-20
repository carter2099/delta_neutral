# Client wrapper around the Hyperliquid SDK for managing perpetual short positions.
#
# Reads credentials from environment variables by default:
# * +HYPERLIQUID_PRIVATE_KEY+ — signing key for exchange actions
# * +HYPERLIQUID_WALLET_ADDRESS+ — address used for info queries
# * +HYPERLIQUID_TESTNET+ — set to +"false"+ to use mainnet (default: testnet)
#
# @example Open a short position
#   service = HyperliquidService.new
#   service.open_short(asset: "ETH", size: BigDecimal("0.5"))
class HyperliquidService
  # @param private_key [String, nil] Hyperliquid signing key; falls back to
  #   +HYPERLIQUID_PRIVATE_KEY+
  # @param wallet_address [String, nil] wallet address for queries; falls back
  #   to +HYPERLIQUID_WALLET_ADDRESS+
  # @param testnet [Boolean, nil] use testnet if +true+; falls back to the
  #   +HYPERLIQUID_TESTNET+ env var (default: +true+)
  def initialize(private_key: nil, wallet_address: nil, testnet: nil)
    @private_key = private_key || ENV.fetch("HYPERLIQUID_PRIVATE_KEY")
    @wallet_address = wallet_address || ENV.fetch("HYPERLIQUID_WALLET_ADDRESS")
    @testnet = testnet.nil? ? ENV.fetch("HYPERLIQUID_TESTNET", "true") == "true" : testnet
  end

  # Opens a market-order short position for the given asset.
  #
  # @param asset [String] the coin symbol (e.g. +"ETH"+)
  # @param size [BigDecimal] position size in base units
  # @return [Hash] the SDK response from the exchange
  def open_short(asset:, size:)
    sdk.exchange.market_order(coin: asset, is_buy: false, size: size)
  end

  # Closes an open short position for the given asset.
  #
  # Silently returns +nil+ if no open position exists for the asset.
  #
  # @param asset [String] the coin symbol (e.g. +"ETH"+)
  # @param size [BigDecimal, nil] amount to close; +nil+ closes the full position
  # @return [Hash, nil] the SDK response, or +nil+ if no position was open
  def close_short(asset:, size: nil)
    sdk.exchange.market_close(coin: asset, size: size)
  rescue ArgumentError => e
    # market_close raises ArgumentError if no open position exists
    raise unless e.message.include?("No open position found")
    Rails.logger.warn("No open position to close for #{asset}: #{e.message}")
    nil
  end

  # Returns all open perpetual positions for the configured wallet.
  #
  # @return [Array<Hash>] each hash includes +:asset+, +:size+,
  #   +:entry_price+, +:unrealized_pnl+, +:return_on_equity+, and
  #   +:liquidation_price+
  def get_positions
    state = sdk.info.user_state(@wallet_address)
    (state["assetPositions"] || []).map do |ap|
      pos = ap["position"]
      {
        asset: pos["coin"],
        size: BigDecimal(pos["szi"]),
        entry_price: BigDecimal(pos["entryPx"]),
        unrealized_pnl: BigDecimal(pos["unrealizedPnl"]),
        return_on_equity: BigDecimal(pos["returnOnEquity"]),
        liquidation_price: pos["liquidationPx"] ? BigDecimal(pos["liquidationPx"]) : nil
      }
    end
  end

  # Returns the open position for a specific asset, or +nil+ if none exists.
  #
  # @param asset [String] the coin symbol
  # @return [Hash, nil] position hash (see {#get_positions}) or +nil+
  def get_position(asset)
    get_positions.find { |p| p[:asset] == asset }
  end

  # Returns the unrealized P&L for a specific asset position.
  #
  # @param asset [String] the coin symbol
  # @return [BigDecimal] unrealized P&L, or +0+ if no position is open
  def unrealized_pnl(asset)
    pos = get_position(asset)
    pos ? pos[:unrealized_pnl] : BigDecimal("0")
  end

  # Returns all fills for the wallet since the given timestamp.
  #
  # @param start_time [Time] only return fills at or after this time
  # @return [Array<Hash>] raw fill objects from the Hyperliquid API
  def user_fills(start_time:)
    sdk.info.user_fills_by_time(@wallet_address, start_time.to_i * 1000)
  end

  private

  # Returns a memoized Hyperliquid SDK instance.
  #
  # @return [Hyperliquid]
  def sdk
    @sdk ||= Hyperliquid.new(private_key: @private_key, testnet: @testnet)
  end
end
