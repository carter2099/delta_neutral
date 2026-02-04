module Uniswap
  class LiquidityMath
    Q96 = BigDecimal(2**96)

    class << self
      # Calculate token0 amount from liquidity and tick range
      # Δx = L * (1/√Pc - 1/√Pb) when Pa <= Pc < Pb
      # Δx = L * (1/√Pa - 1/√Pb) when Pc < Pa (all token0)
      # Δx = 0 when Pc >= Pb (all token1)
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

      # Calculate token1 amount from liquidity and tick range
      # Δy = L * (√Pc - √Pa) when Pa < Pc <= Pb
      # Δy = L * (√Pb - √Pa) when Pc > Pb (all token1)
      # Δy = 0 when Pc <= Pa (all token0)
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

      # Calculate both token amounts at once
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

      # Calculate amounts from raw subgraph data
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
