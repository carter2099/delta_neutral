module Hyperliquid
  class OrderExecutor
    class ExecutionError < StandardError; end

    def initialize(client:, paper_trading: false)
      @client = client
      @paper_trading = paper_trading
    end

    def paper_trading?
      @paper_trading
    end

    # Execute a list of hedge adjustments
    # adjustments: [{ asset: "ETH", current_size: -1.5, target_size: -2.0 }, ...]
    def execute_adjustments(adjustments)
      results = []

      adjustments.each do |adjustment|
        result = execute_single_adjustment(adjustment)
        results << result
      end

      {
        success: results.all? { |r| r[:success] },
        results: results
      }
    end

    # Execute a single adjustment
    def execute_single_adjustment(adjustment)
      asset = adjustment[:asset]
      current_size = adjustment[:current_size] || 0
      target_size = adjustment[:target_size]
      delta = target_size - current_size

      return { success: true, asset: asset, action: :none, reason: "No change needed" } if delta.abs < 0.0001

      action = delta.negative? ? :short : :cover

      if @paper_trading
        simulate_order(asset: asset, size: delta, action: action)
      else
        execute_order(asset: asset, size: delta, action: action)
      end
    rescue => e
      { success: false, asset: asset, error: e.message }
    end

    # Close all positions for given assets
    def close_positions(assets)
      results = []

      assets.each do |asset|
        result = if @paper_trading
          { success: true, asset: asset, action: :close, simulated: true }
        else
          close_result = @client.close_position(asset: asset)
          { success: true, asset: asset, action: :close, response: close_result }
        end
        results << result
      rescue => e
        results << { success: false, asset: asset, error: e.message }
      end

      results
    end

    private

    def simulate_order(asset:, size:, action:)
      price = @client.market_price(asset)

      {
        success: true,
        asset: asset,
        action: action,
        size: size,
        simulated: true,
        simulated_price: price,
        simulated_value: (size.abs * price).round(2),
        timestamp: Time.current
      }
    end

    def execute_order(asset:, size:, action:)
      result = @client.place_order(
        asset: asset,
        size: size,
        order_type: :market
      )

      {
        success: true,
        asset: asset,
        action: action,
        size: size,
        executed: true,
        response: result,
        timestamp: Time.current
      }
    end
  end
end
