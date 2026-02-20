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
  # Raised when a Hyperliquid order is rejected (e.g. below minimum value).
  class OrderError < StandardError; end

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
    Rails.logger.debug { "[HyperliquidService] open_short: asset=#{asset}, size=#{size}" }
    result = sdk.exchange.market_order(coin: asset, is_buy: false, size: size)
    Rails.logger.debug { "[HyperliquidService] open_short result: #{result.inspect.truncate(200)}" }
    validate_order_response!(result)
    result
  end

  # Closes an open short position for the given asset.
  #
  # Silently returns +nil+ if no open position exists for the asset.
  #
  # @param asset [String] the coin symbol (e.g. +"ETH"+)
  # @param size [BigDecimal, nil] amount to close; +nil+ closes the full position
  # @return [Hash, nil] the SDK response, or +nil+ if no position was open
  def close_short(asset:, size: nil)
    Rails.logger.debug { "[HyperliquidService] close_short: asset=#{asset}, size=#{size || 'full'}" }
    result = sdk.exchange.market_close(coin: asset, size: size)
    Rails.logger.debug { "[HyperliquidService] close_short result: #{result.inspect.truncate(200)}" }
    result
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
    Rails.logger.debug { "[HyperliquidService] get_positions for #{@wallet_address}" }
    state = sdk.info.user_state(@wallet_address)
    positions = (state["assetPositions"] || []).map do |ap|
      pos = ap["position"]
      size = BigDecimal(pos["szi"])
      position_value = BigDecimal(pos["positionValue"])
      {
        asset: pos["coin"],
        size: size,
        entry_price: BigDecimal(pos["entryPx"]),
        position_value: position_value,
        margin_used: BigDecimal(pos["marginUsed"]),
        mark_price: size.zero? ? BigDecimal("0") : (position_value / size.abs),
        unrealized_pnl: BigDecimal(pos["unrealizedPnl"]),
        return_on_equity: BigDecimal(pos["returnOnEquity"]),
        liquidation_price: pos["liquidationPx"] ? BigDecimal(pos["liquidationPx"]) : nil
      }
    end
    Rails.logger.debug { "[HyperliquidService] get_positions returned #{positions.size} position(s): #{positions.map { |p| "#{p[:asset]} size=#{p[:size]}" }.join(", ")}" }
    positions
  end

  # Returns the open position for a specific asset, or +nil+ if none exists.
  #
  # @param asset [String] the coin symbol
  # @return [Hash, nil] position hash (see {#get_positions}) or +nil+
  def get_position(asset)
    pos = get_positions.find { |p| p[:asset] == asset }
    Rails.logger.debug { "[HyperliquidService] get_position(#{asset}): #{pos ? "size=#{pos[:size]}, unrealized_pnl=#{pos[:unrealized_pnl]}" : "not found"}" }
    pos
  end

  # Returns the unrealized P&L for a specific asset position.
  #
  # @param asset [String] the coin symbol
  # @return [BigDecimal] unrealized P&L, or +0+ if no position is open
  def unrealized_pnl(asset)
    pos = get_position(asset)
    pos ? pos[:unrealized_pnl] : BigDecimal("0")
  end

  # Returns the size decimal precision for a given asset.
  #
  # Fetches and caches the metadata for all perp assets on first call.
  #
  # @param asset [String] the coin symbol (e.g. +"ETH"+)
  # @return [Integer] the number of decimal places allowed for order sizes
  def sz_decimals(asset)
    @sz_decimals_cache ||= begin
      meta = sdk.info.meta
      (meta["universe"] || []).each_with_object({}) do |a, h|
        h[a["name"]] = a["szDecimals"]
      end
    end
    @sz_decimals_cache.fetch(asset) do
      raise ArgumentError, "Unknown asset or no szDecimals available: #{asset}"
    end
  end

  # Returns all fills for the wallet since the given timestamp.
  #
  # @param start_time [Time] only return fills at or after this time
  # @return [Array<Hash>] raw fill objects from the Hyperliquid API
  def user_fills(start_time:)
    Rails.logger.debug { "[HyperliquidService] user_fills since #{start_time}" }
    fills = sdk.info.user_fills_by_time(@wallet_address, start_time.to_i * 1000)
    Rails.logger.debug { "[HyperliquidService] user_fills returned #{fills.size} fill(s)" }
    fills
  end

  # Updates leverage and margin mode for an asset before placing orders.
  #
  # @param asset [String] the coin symbol (e.g. +"ETH"+)
  # @param leverage [Integer] desired leverage multiplier
  # @param is_cross [Boolean] +true+ for cross margin, +false+ for isolated
  # @return [Hash] the SDK response
  def set_leverage(asset:, leverage:, is_cross:)
    Rails.logger.debug { "[HyperliquidService] set_leverage: asset=#{asset}, leverage=#{leverage}, is_cross=#{is_cross}" }
    result = sdk.exchange.update_leverage(coin: asset, leverage: leverage, is_cross: is_cross)
    Rails.logger.debug { "[HyperliquidService] set_leverage result: #{result.inspect.truncate(200)}" }
    result
  end

  private

  # Raises if the Hyperliquid order response contains an error status.
  #
  # The SDK returns +"status" => "ok"+ even when individual order statuses
  # contain errors (e.g. minimum value violations). This method checks for
  # those nested errors and raises an +OrderError+ so callers don't
  # silently treat failed orders as successful.
  #
  # @param result [Hash] the SDK response from a market order
  # @raise [OrderError] if any order status contains an error
  # @return [void]
  def validate_order_response!(result)
    statuses = result.dig("response", "data", "statuses") || []
    errors = statuses.filter_map { |s| s["error"] }
    return if errors.empty?

    raise OrderError, errors.join("; ")
  end

  # Returns a memoized Hyperliquid SDK instance.
  #
  # @return [Hyperliquid]
  def sdk
    @sdk ||= Hyperliquid.new(private_key: @private_key, testnet: @testnet)
  end
end
