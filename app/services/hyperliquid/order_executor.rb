module Hyperliquid
  # Executes hedge adjustments on Hyperliquid, with paper trading support.
  #
  # Accepts adjustment hashes (from {Hedging::Calculator#calculate_adjustments})
  # and either executes real market orders via {ClientWrapper} or simulates them
  # with current market prices when in paper trading mode.
  #
  # @example Paper trading
  #   executor = Hyperliquid::OrderExecutor.new(client: client, paper_trading: true)
  #   result = executor.execute_adjustments([
  #     { asset: "ETH", current_size: -1.5, target_size: -2.0 }
  #   ])
  #   result[:success] #=> true
  #   result[:results].first[:simulated] #=> true
  class OrderExecutor
    # Raised when order execution fails.
    class ExecutionError < StandardError; end

    # @param client [Hyperliquid::ClientWrapper] the HL API client
    # @param paper_trading [Boolean] simulate orders instead of executing (default: false)
    def initialize(client:, paper_trading: false)
      @client = client
      @paper_trading = paper_trading
    end

    # @return [Boolean] whether this executor is in paper trading mode
    def paper_trading?
      @paper_trading
    end

    # Execute a batch of hedge adjustments sequentially.
    #
    # @param adjustments [Array<Hash>] adjustments with keys +:asset+,
    #   +:current_size+, +:target_size+
    # @return [Hash] +{ success: Boolean, results: Array<Hash> }+
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

    # Execute or simulate a single hedge adjustment.
    #
    # @param adjustment [Hash] with keys +:asset+, +:current_size+, +:target_size+
    # @return [Hash] result with +:success+, +:asset+, +:action+ (and +:simulated+ if paper trading)
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

    # Close all positions for the given assets.
    #
    # @param assets [Array<String>] asset symbols to close (e.g., +["ETH", "ARB"]+)
    # @return [Array<Hash>] per-asset results with +:success+, +:asset+, +:action+
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
