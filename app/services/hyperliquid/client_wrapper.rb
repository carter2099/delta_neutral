module Hyperliquid
  class ClientWrapper
    class Error < StandardError; end
    class ConfigurationError < Error; end
    class ApiError < Error; end

    attr_reader :testnet

    def initialize(testnet: false)
      @testnet = testnet
      @sdk = build_sdk
    end

    def account_state(address = nil)
      address ||= wallet_address
      raise ConfigurationError, "No wallet address configured" unless address

      response = @sdk.info.user_state(address)
      normalize_account_state(response)
    rescue => e
      raise ApiError, "Failed to fetch account state: #{e.message}"
    end

    def positions(address = nil)
      state = account_state(address)
      state[:positions]
    end

    def open_orders(address = nil)
      address ||= wallet_address
      response = @sdk.info.open_orders(address)
      response.map { |o| normalize_order(o) }
    rescue => e
      raise ApiError, "Failed to fetch open orders: #{e.message}"
    end

    def available_markets
      response = @sdk.info.meta
      perps = response["universe"] || []
      perps.map { |p| normalize_market(p) }
    rescue => e
      raise ApiError, "Failed to fetch markets: #{e.message}"
    end

    def market_price(asset)
      response = @sdk.info.all_mids
      price = response[asset]
      raise ApiError, "No price found for #{asset}" unless price
      price.to_f
    rescue => e
      raise ApiError, "Failed to fetch price for #{asset}: #{e.message}"
    end

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

    def cancel_order(asset:, order_id:)
      raise ConfigurationError, "Private key not configured" unless private_key_configured?

      @sdk.exchange.cancel_order(coin: asset, oid: order_id)
    rescue => e
      raise ApiError, "Failed to cancel order: #{e.message}"
    end

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
