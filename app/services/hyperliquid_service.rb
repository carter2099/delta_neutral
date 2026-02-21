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

  # Maps wrapped token symbols from Uniswap to Hyperliquid trading symbols.
  SYMBOL_MAP = {
    "WETH" => "ETH",
    "WBTC" => "BTC",
    "WMATIC" => "MATIC",
    "WAVAX" => "AVAX",
    "WSOL" => "SOL"
  }.freeze

  # Translates a Uniswap token symbol to its Hyperliquid equivalent.
  #
  # Returns the symbol unchanged if no mapping exists (e.g. +"USDC"+ stays +"USDC"+).
  #
  # @param symbol [String] the token symbol (e.g. +"WETH"+)
  # @return [String] the Hyperliquid trading symbol (e.g. +"ETH"+)
  def self.normalize_symbol(symbol)
    SYMBOL_MAP.fetch(symbol, symbol)
  end

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
  # @param vault_address [String, nil] subaccount address to trade on; +nil+ for main account
  # @return [Hash] the SDK response from the exchange
  def open_short(asset:, size:, vault_address: nil)
    Rails.logger.debug { "[HyperliquidService] open_short: asset=#{asset}, size=#{size}, vault_address=#{vault_address}" }
    opts = { coin: asset, is_buy: false, size: size }
    opts[:vault_address] = vault_address if vault_address
    result = sdk.exchange.market_order(**opts)
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
  # @param vault_address [String, nil] subaccount address to trade on; +nil+ for main account
  # @return [Hash, nil] the SDK response, or +nil+ if no position was open
  def close_short(asset:, size: nil, vault_address: nil)
    Rails.logger.debug { "[HyperliquidService] close_short: asset=#{asset}, size=#{size || 'full'}, vault_address=#{vault_address}" }
    opts = { coin: asset, size: size }
    opts[:vault_address] = vault_address if vault_address
    result = sdk.exchange.market_close(**opts)
    Rails.logger.debug { "[HyperliquidService] close_short result: #{result.inspect.truncate(200)}" }
    result
  rescue ArgumentError => e
    # market_close raises ArgumentError if no open position exists
    raise unless e.message.include?("No open position found")
    Rails.logger.warn("No open position to close for #{asset}: #{e.message}")
    nil
  end

  # Returns all open perpetual positions for the given address.
  #
  # @param address [String, nil] wallet/subaccount address; defaults to the main wallet
  # @return [Array<Hash>] each hash includes +:asset+, +:size+,
  #   +:entry_price+, +:unrealized_pnl+, and +:liquidation_price+
  def get_positions(address: nil)
    addr = address || @wallet_address
    Rails.logger.debug { "[HyperliquidService] get_positions for #{addr}" }
    state = sdk.info.user_state(addr)
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
        liquidation_price: pos["liquidationPx"] ? BigDecimal(pos["liquidationPx"]) : nil
      }
    end
    Rails.logger.debug { "[HyperliquidService] get_positions returned #{positions.size} position(s): #{positions.map { |p| "#{p[:asset]} size=#{p[:size]}" }.join(", ")}" }
    positions
  end

  # Returns the open position for a specific asset, or +nil+ if none exists.
  #
  # @param asset [String] the coin symbol
  # @param address [String, nil] wallet/subaccount address; defaults to the main wallet
  # @return [Hash, nil] position hash (see {#get_positions}) or +nil+
  def get_position(asset, address: nil)
    pos = get_positions(address: address).find { |p| p[:asset] == asset }
    Rails.logger.debug { "[HyperliquidService] get_position(#{asset}): #{pos ? "size=#{pos[:size]}, unrealized_pnl=#{pos[:unrealized_pnl]}" : "not found"}" }
    pos
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

  # Returns all fills for the given address since the given timestamp.
  #
  # @param start_time [Time] only return fills at or after this time
  # @param address [String, nil] wallet/subaccount address; defaults to the main wallet
  # @return [Array<Hash>] raw fill objects from the Hyperliquid API
  def user_fills(start_time:, address: nil)
    addr = address || @wallet_address
    Rails.logger.debug { "[HyperliquidService] user_fills since #{start_time} for #{addr}" }
    fills = sdk.info.user_fills_by_time(addr, start_time.to_i * 1000)
    Rails.logger.debug { "[HyperliquidService] user_fills returned #{fills.size} fill(s)" }
    fills
  end

  # Updates leverage and margin mode for an asset before placing orders.
  #
  # @param asset [String] the coin symbol (e.g. +"ETH"+)
  # @param leverage [Integer] desired leverage multiplier
  # @param is_cross [Boolean] +true+ for cross margin, +false+ for isolated
  # @param vault_address [String, nil] subaccount address; +nil+ for main account
  # @return [Hash] the SDK response
  def set_leverage(asset:, leverage:, is_cross:, vault_address: nil)
    Rails.logger.debug { "[HyperliquidService] set_leverage: asset=#{asset}, leverage=#{leverage}, is_cross=#{is_cross}, vault_address=#{vault_address}" }
    opts = { coin: asset, leverage: leverage, is_cross: is_cross }
    opts[:vault_address] = vault_address if vault_address
    result = sdk.exchange.update_leverage(**opts)
    Rails.logger.debug { "[HyperliquidService] set_leverage result: #{result.inspect.truncate(200)}" }
    result
  end

  # Creates a new Hyperliquid subaccount.
  #
  # @param name [String] the subaccount name
  # @return [Hash] the SDK response containing the subaccount address
  def create_subaccount(name:)
    Rails.logger.debug { "[HyperliquidService] create_subaccount: name=#{name}" }
    result = sdk.exchange.create_sub_account(name: name)
    Rails.logger.debug { "[HyperliquidService] create_subaccount result: #{result.inspect.truncate(200)}" }
    result
  end

  # Transfers USDC from main account to a subaccount.
  #
  # @param subaccount_address [String] the subaccount address
  # @param usd [BigDecimal] amount of USDC to transfer
  # @return [Hash] the SDK response
  def transfer_to_subaccount(subaccount_address:, usd:)
    Rails.logger.debug { "[HyperliquidService] transfer_to_subaccount: #{usd} USDC → #{subaccount_address}" }
    result = sdk.exchange.sub_account_transfer(sub_account_user: subaccount_address, is_deposit: true, usd: usd)
    Rails.logger.debug { "[HyperliquidService] transfer_to_subaccount result: #{result.inspect.truncate(200)}" }
    result
  end

  # Withdraws USDC from a subaccount back to the main account.
  #
  # @param subaccount_address [String] the subaccount address
  # @param usd [BigDecimal] amount of USDC to withdraw
  # @return [Hash] the SDK response
  def withdraw_from_subaccount(subaccount_address:, usd:)
    Rails.logger.debug { "[HyperliquidService] withdraw_from_subaccount: #{usd} USDC ← #{subaccount_address}" }
    result = sdk.exchange.sub_account_transfer(sub_account_user: subaccount_address, is_deposit: false, usd: usd)
    Rails.logger.debug { "[HyperliquidService] withdraw_from_subaccount result: #{result.inspect.truncate(200)}" }
    result
  end

  # Returns all subaccounts for the main wallet.
  #
  # @return [Array<Hash>] subaccount objects with +"subAccountUser"+ addresses
  def list_subaccounts
    Rails.logger.debug { "[HyperliquidService] list_subaccounts for #{@wallet_address}" }
    result = sdk.info.user_subaccounts(@wallet_address)
    Rails.logger.debug { "[HyperliquidService] list_subaccounts returned #{result.size} subaccount(s)" }
    result
  end

  # Returns the account balance for a given address.
  #
  # @param address [String] wallet or subaccount address
  # @return [Hash] with +:withdrawable+ and +:account_value+ as BigDecimals
  def account_balance(address)
    Rails.logger.debug { "[HyperliquidService] account_balance for #{address}" }
    state = sdk.info.user_state(address)
    margin = state["marginSummary"] || {}
    {
      withdrawable: BigDecimal(margin["totalRawUsd"] || margin["accountValue"] || "0"),
      account_value: BigDecimal(margin["accountValue"] || "0")
    }
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
