module Hyperliquid
  # Wrapper around the +hyperliquid+ gem SDK providing normalized access to
  # Hyperliquid exchange data and trading operations.
  #
  # Credentials are sourced from Rails encrypted credentials or environment
  # variables (+HYPERLIQUID_WALLET_ADDRESS+, +HYPERLIQUID_PRIVATE_KEY+).
  #
  # @example Read-only usage
  #   client = Hyperliquid::ClientWrapper.new(testnet: true)
  #   client.positions #=> [{ asset: "ETH", size: -2.0, ... }]
  #
  # @example Trading (requires private key)
  #   client = Hyperliquid::ClientWrapper.new
  #   client.place_order(asset: "ETH", size: -1.5, order_type: :market)
  class ClientWrapper
    class Error < StandardError; end
    # Raised when required credentials (wallet address, private key) are missing.
    class ConfigurationError < Error; end
    # Raised when an API call to Hyperliquid fails.
    class ApiError < Error; end

    # @return [Boolean] whether this client is connected to HL testnet
    attr_reader :testnet

    # @param testnet [Boolean] connect to HL testnet instead of mainnet (default: false)
    def initialize(testnet: false)
      @testnet = testnet
      @sdk = build_sdk
    end

    # Fetch the full account state including margin summary and positions.
    #
    # @param address [String, nil] wallet address (defaults to configured address)
    # @return [Hash] normalized account state with keys +:account_value+,
    #   +:total_margin_used+, +:positions+, etc.
    # @raise [ConfigurationError] if no wallet address is configured
    # @raise [ApiError] on API failure
    def account_state(address = nil)
      address ||= wallet_address
      raise ConfigurationError, "No wallet address configured" unless address

      response = @sdk.info.user_state(address)
      normalize_account_state(response)
    rescue => e
      raise ApiError, "Failed to fetch account state: #{e.message}"
    end

    # Fetch current open positions.
    #
    # @param address [String, nil] wallet address (defaults to configured address)
    # @return [Array<Hash>] normalized positions with keys +:asset+, +:size+,
    #   +:entry_price+, +:unrealized_pnl+, etc.
    # @raise [ApiError] on API failure
    def positions(address = nil)
      state = account_state(address)
      state[:positions]
    end

    # Fetch all open (unfilled) orders.
    #
    # @param address [String, nil] wallet address (defaults to configured address)
    # @return [Array<Hash>] normalized orders with keys +:order_id+, +:asset+,
    #   +:side+, +:size+, +:price+, +:status+
    # @raise [ApiError] on API failure
    def open_orders(address = nil)
      address ||= wallet_address
      response = @sdk.info.open_orders(address)
      response.map { |o| normalize_order(o) }
    rescue => e
      raise ApiError, "Failed to fetch open orders: #{e.message}"
    end

    # Fetch all available perpetual markets on Hyperliquid.
    #
    # @return [Array<Hash>] markets with keys +:name+, +:sz_decimals+, +:max_leverage+
    # @raise [ApiError] on API failure
    def available_markets
      response = @sdk.info.meta
      perps = response["universe"] || []
      perps.map { |p| normalize_market(p) }
    rescue => e
      raise ApiError, "Failed to fetch markets: #{e.message}"
    end

    # Get the current mid price for a given asset.
    #
    # @param asset [String] the asset symbol (e.g., "ETH", "BTC")
    # @return [Float] the current mid price in USD
    # @raise [ApiError] if no price is found or API fails
    def market_price(asset)
      response = @sdk.info.all_mids
      price = response[asset]
      raise ApiError, "No price found for #{asset}" unless price
      price.to_f
    rescue => e
      raise ApiError, "Failed to fetch price for #{asset}: #{e.message}"
    end

    # Place an order on Hyperliquid.
    #
    # @param asset [String] the asset symbol (e.g., "ETH")
    # @param size [Float] the order size (positive = buy/long, negative = sell/short)
    # @param price [Float, nil] limit price (required for +:limit+ orders)
    # @param reduce_only [Boolean] whether the order can only reduce a position (default: false)
    # @param order_type [Symbol] +:market+ or +:limit+ (default: +:market+)
    # @return [Hash] order response with +:status+ and +:response+ keys
    # @raise [ConfigurationError] if private key is not configured
    # @raise [ApiError] on API failure
    def place_order(asset:, size:, price: nil, reduce_only: false, order_type: :market)
      raise ConfigurationError, "Private key not configured" unless private_key_configured?

      is_buy = size.positive?
      params = {
        coin: asset,
        is_buy: is_buy,
        sz: size.abs.to_f,
        reduce_only: reduce_only
      }

      if order_type == :limit && price
        params[:limit_px] = price.to_f
        params[:order_type] = { limit: { tif: "Gtc" } }
      else
        params[:limit_px] = nil
        params[:order_type] = { market: {} }
      end

      response = @sdk.exchange.place_order(**params)
      normalize_order_response(response)
    rescue => e
      raise ApiError, "Failed to place order: #{e.message}"
    end

    # Cancel an open order.
    #
    # @param asset [String] the asset symbol
    # @param order_id [String, Integer] the order ID to cancel
    # @raise [ConfigurationError] if private key is not configured
    # @raise [ApiError] on API failure
    def cancel_order(asset:, order_id:)
      raise ConfigurationError, "Private key not configured" unless private_key_configured?

      @sdk.exchange.cancel_order(coin: asset, oid: order_id)
    rescue => e
      raise ApiError, "Failed to cancel order: #{e.message}"
    end

    # Close an entire position for a given asset by placing an opposite market order.
    #
    # @param asset [String] the asset symbol
    # @return [Hash] order result, or +{ status: "no_position" }+ if no position exists
    # @raise [ConfigurationError] if private key is not configured
    # @raise [ApiError] on API failure
    def close_position(asset:)
      raise ConfigurationError, "Private key not configured" unless private_key_configured?

      current_positions = positions
      position = current_positions.find { |p| p[:asset] == asset }

      return { status: "no_position" } unless position && position[:size] != 0

      # Close by placing opposite order
      place_order(
        asset: asset,
        size: -position[:size],
        reduce_only: true,
        order_type: :market
      )
    end

    private

    def build_sdk
      config = {
        testnet: @testnet
      }

      if private_key_configured?
        config[:private_key] = private_key
      end

      ::Hyperliquid::Client.new(**config)
    end

    def wallet_address
      Rails.application.credentials.dig(:hyperliquid, :wallet_address) ||
        ENV["HYPERLIQUID_WALLET_ADDRESS"]
    end

    def private_key
      Rails.application.credentials.dig(:hyperliquid, :private_key) ||
        ENV["HYPERLIQUID_PRIVATE_KEY"]
    end

    def private_key_configured?
      private_key.present?
    end

    def normalize_account_state(response)
      margin_summary = response["marginSummary"] || {}
      asset_positions = response["assetPositions"] || []

      {
        account_value: margin_summary["accountValue"]&.to_f || 0,
        total_margin_used: margin_summary["totalMarginUsed"]&.to_f || 0,
        total_ntl_pos: margin_summary["totalNtlPos"]&.to_f || 0,
        total_raw_usd: margin_summary["totalRawUsd"]&.to_f || 0,
        withdrawable: response["withdrawable"]&.to_f || 0,
        positions: asset_positions.map { |p| normalize_position(p) }
      }
    end

    def normalize_position(position_data)
      pos = position_data["position"] || position_data
      {
        asset: pos["coin"],
        size: pos["szi"]&.to_f || 0,
        entry_price: pos["entryPx"]&.to_f,
        position_value: pos["positionValue"]&.to_f,
        unrealized_pnl: pos["unrealizedPnl"]&.to_f,
        return_on_equity: pos["returnOnEquity"]&.to_f,
        liquidation_price: pos["liquidationPx"]&.to_f,
        margin_used: pos["marginUsed"]&.to_f,
        leverage: pos["leverage"]&.to_i
      }
    end

    def normalize_order(order)
      {
        order_id: order["oid"],
        asset: order["coin"],
        side: order["side"],
        size: order["sz"]&.to_f,
        price: order["limitPx"]&.to_f,
        filled: order["filled"]&.to_f || 0,
        status: order["status"],
        timestamp: order["timestamp"]
      }
    end

    def normalize_market(market)
      {
        name: market["name"],
        sz_decimals: market["szDecimals"],
        max_leverage: market["maxLeverage"]
      }
    end

    def normalize_order_response(response)
      status = response.dig("status") || response.dig("response", "data", "statuses", 0)
      {
        status: status,
        response: response
      }
    end
  end
end
