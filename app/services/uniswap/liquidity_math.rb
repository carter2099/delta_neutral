module Uniswap
  # Calculates token amounts held within a Uniswap V3 concentrated liquidity position.
  #
  # Uses the Uniswap V3 formulas to determine how much of each token is held
  # given liquidity, current price, and the position's tick range:
  #   Δx = L * (1/√Pc - 1/√Pb)   — token0 when price is in range
  #   Δy = L * (√Pc - √Pa)        — token1 when price is in range
  #
  # Handles all three cases: price below range (all token0), in range (mixed),
  # and above range (all token1).
  #
  # @see Uniswap::TickMath for tick/price conversion utilities
  # @see https://uniswap.org/whitepaper-v3.pdf Section 6.3
  class LiquidityMath
    # @return [BigDecimal] 2^96, the Q96 fixed-point scaling factor
    Q96 = BigDecimal(2**96)

    class << self
      # Calculate the token0 amount held in a position given sqrt prices in Q96 format.
      #
      # @param liquidity [Numeric, String] the position's liquidity value
      # @param sqrt_price_current [Numeric, String] the pool's current sqrt price (Q96)
      # @param sqrt_price_lower [Numeric, String] the lower tick's sqrt price (Q96)
      # @param sqrt_price_upper [Numeric, String] the upper tick's sqrt price (Q96)
      # @param decimals [Integer] token0 decimals for unit conversion (default: 18)
      # @return [BigDecimal] the token0 amount in human-readable units
      def get_token0_amount(liquidity:, sqrt_price_current:, sqrt_price_lower:, sqrt_price_upper:, decimals: 18)
        liquidity = BigDecimal(liquidity.to_s)
        sqrt_pc = BigDecimal(sqrt_price_current.to_s) / Q96
        sqrt_pa = BigDecimal(sqrt_price_lower.to_s) / Q96
        sqrt_pb = BigDecimal(sqrt_price_upper.to_s) / Q96

        amount = if sqrt_pc <= sqrt_pa
          # Price below range - position is all token0
          liquidity * (1 / sqrt_pa - 1 / sqrt_pb)
        elsif sqrt_pc >= sqrt_pb
          # Price above range - position is all token1
          BigDecimal(0)
        else
          # Price in range
          liquidity * (1 / sqrt_pc - 1 / sqrt_pb)
        end

        # Convert to token units
        amount / BigDecimal(10**decimals)
      end

      # Calculate the token1 amount held in a position given sqrt prices in Q96 format.
      #
      # @param liquidity [Numeric, String] the position's liquidity value
      # @param sqrt_price_current [Numeric, String] the pool's current sqrt price (Q96)
      # @param sqrt_price_lower [Numeric, String] the lower tick's sqrt price (Q96)
      # @param sqrt_price_upper [Numeric, String] the upper tick's sqrt price (Q96)
      # @param decimals [Integer] token1 decimals for unit conversion (default: 18)
      # @return [BigDecimal] the token1 amount in human-readable units
      def get_token1_amount(liquidity:, sqrt_price_current:, sqrt_price_lower:, sqrt_price_upper:, decimals: 18)
        liquidity = BigDecimal(liquidity.to_s)
        sqrt_pc = BigDecimal(sqrt_price_current.to_s) / Q96
        sqrt_pa = BigDecimal(sqrt_price_lower.to_s) / Q96
        sqrt_pb = BigDecimal(sqrt_price_upper.to_s) / Q96

        amount = if sqrt_pc <= sqrt_pa
          # Price below range - position is all token0
          BigDecimal(0)
        elsif sqrt_pc >= sqrt_pb
          # Price above range - position is all token1
          liquidity * (sqrt_pb - sqrt_pa)
        else
          # Price in range
          liquidity * (sqrt_pc - sqrt_pa)
        end

        # Convert to token units
        amount / BigDecimal(10**decimals)
      end

      # Calculate both token amounts at once from tick values.
      #
      # Converts ticks to sqrt prices via {TickMath} and delegates to
      # {.get_token0_amount} and {.get_token1_amount}.
      #
      # @param liquidity [Numeric, String] the position's liquidity value
      # @param current_tick [Integer] the pool's current tick
      # @param tick_lower [Integer] the position's lower tick boundary
      # @param tick_upper [Integer] the position's upper tick boundary
      # @param token0_decimals [Integer] token0 decimals (default: 18)
      # @param token1_decimals [Integer] token1 decimals (default: 18)
      # @return [Hash{Symbol => BigDecimal}] +{ token0: amount, token1: amount }+
      #
      # @example
      #   Uniswap::LiquidityMath.get_amounts(
      #     liquidity: "1000000000000000000",
      #     current_tick: 0, tick_lower: -1000, tick_upper: 1000,
      #     token0_decimals: 18, token1_decimals: 6
      #   )
      def get_amounts(liquidity:, current_tick:, tick_lower:, tick_upper:, token0_decimals: 18, token1_decimals: 18)
        sqrt_price_current = TickMath.get_sqrt_ratio_at_tick(current_tick)
        sqrt_price_lower = TickMath.get_sqrt_ratio_at_tick(tick_lower)
        sqrt_price_upper = TickMath.get_sqrt_ratio_at_tick(tick_upper)

        {
          token0: get_token0_amount(
            liquidity: liquidity,
            sqrt_price_current: sqrt_price_current,
            sqrt_price_lower: sqrt_price_lower,
            sqrt_price_upper: sqrt_price_upper,
            decimals: token0_decimals
          ),
          token1: get_token1_amount(
            liquidity: liquidity,
            sqrt_price_current: sqrt_price_current,
            sqrt_price_lower: sqrt_price_lower,
            sqrt_price_upper: sqrt_price_upper,
            decimals: token1_decimals
          )
        }
      end

      # Calculate token amounts directly from raw subgraph position data.
      #
      # Extracts liquidity, tick range, current tick, and token decimals from the
      # subgraph response hash and delegates to {.get_amounts}. Handles both
      # symbol and string keys, and nested tick hashes (+{ "tickIdx" => "0" }+).
      #
      # @param position_data [Hash] raw position data from {Subgraph::PositionFetcher}
      # @return [Hash{Symbol => BigDecimal}] +{ token0: amount, token1: amount }+
      def calculate_from_position_data(position_data)
        liquidity = position_data[:liquidity] || position_data["liquidity"]

        tick_lower_data = position_data[:tickLower] || position_data["tickLower"]
        tick_upper_data = position_data[:tickUpper] || position_data["tickUpper"]
        tick_lower = extract_tick(tick_lower_data)
        tick_upper = extract_tick(tick_upper_data)

        pool = position_data[:pool] || position_data["pool"]
        current_tick = (pool[:tick] || pool["tick"]).to_i

        token0 = position_data[:token0] || position_data["token0"]
        token1 = position_data[:token1] || position_data["token1"]

        token0_decimals = (token0[:decimals] || token0["decimals"]).to_i
        token1_decimals = (token1[:decimals] || token1["decimals"]).to_i

        get_amounts(
          liquidity: liquidity,
          current_tick: current_tick,
          tick_lower: tick_lower,
          tick_upper: tick_upper,
          token0_decimals: token0_decimals,
          token1_decimals: token1_decimals
        )
      end

      private

      def extract_tick(tick_data)
        if tick_data.is_a?(Hash)
          (tick_data[:tickIdx] || tick_data["tickIdx"]).to_i
        else
          tick_data.to_i
        end
      end
    end
  end
end
