module Uniswap
  class TickMath
    MIN_TICK = -887272
    MAX_TICK = 887272
    MIN_SQRT_RATIO = BigDecimal("4295128739")
    MAX_SQRT_RATIO = BigDecimal("1461446703485210103287273052203988822378723970342")

    Q96 = BigDecimal(2**96)
    Q192 = BigDecimal(2**192)

    class << self
      # Convert tick to sqrt price (Q64.96 format)
      # sqrt(1.0001^tick) * 2^96
      def get_sqrt_ratio_at_tick(tick)
        raise ArgumentError, "Tick out of range" if tick < MIN_TICK || tick > MAX_TICK

        # sqrt(1.0001^tick) = 1.0001^(tick/2)
        sqrt_price = BigDecimal("1.0001") ** (BigDecimal(tick) / 2)
        (sqrt_price * Q96).floor
      end

      # Convert sqrt price to tick
      def get_tick_at_sqrt_ratio(sqrt_ratio_x96)
        sqrt_price = BigDecimal(sqrt_ratio_x96) / Q96
        # tick = log(price) / log(1.0001) = 2 * log(sqrt_price) / log(1.0001)
        (2 * Math.log(sqrt_price.to_f) / Math.log(1.0001)).floor
      end

      # Convert tick to price (token1/token0)
      def tick_to_price(tick, token0_decimals: 18, token1_decimals: 18)
        raw_price = BigDecimal("1.0001") ** tick
        # Adjust for decimal difference
        decimal_adjustment = BigDecimal(10) ** (token0_decimals - token1_decimals)
        raw_price * decimal_adjustment
      end

      # Convert price to tick
      def price_to_tick(price, token0_decimals: 18, token1_decimals: 18)
        decimal_adjustment = BigDecimal(10) ** (token0_decimals - token1_decimals)
        adjusted_price = BigDecimal(price.to_s) / decimal_adjustment
        (Math.log(adjusted_price.to_f) / Math.log(1.0001)).floor
      end

      # Get the sqrt price from a regular price
      def price_to_sqrt_price_x96(price, token0_decimals: 18, token1_decimals: 18)
        decimal_adjustment = BigDecimal(10) ** (token0_decimals - token1_decimals)
        adjusted_price = BigDecimal(price.to_s) / decimal_adjustment
        sqrt_price = Math.sqrt(adjusted_price.to_f)
        (BigDecimal(sqrt_price.to_s) * Q96).floor
      end

      # Get regular price from sqrt price
      def sqrt_price_x96_to_price(sqrt_price_x96, token0_decimals: 18, token1_decimals: 18)
        sqrt_price = BigDecimal(sqrt_price_x96) / Q96
        raw_price = sqrt_price ** 2
        decimal_adjustment = BigDecimal(10) ** (token0_decimals - token1_decimals)
        raw_price * decimal_adjustment
      end
    end
  end
end
