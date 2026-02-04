module Uniswap
  # Uniswap V3 tick-to-price and price-to-tick conversion math.
  #
  # Implements the core formulas from the Uniswap V3 whitepaper:
  #   p(i) = 1.0001^i
  #   sqrtPriceX96 = sqrt(price) * 2^96
  #
  # All sqrt prices use the Q64.96 fixed-point format used on-chain.
  # Decimal adjustments account for differing token decimals (e.g., WETH=18, USDC=6).
  #
  # @see https://uniswap.org/whitepaper-v3.pdf
  class TickMath
    # @return [Integer] the minimum tick supported by Uniswap V3
    MIN_TICK = -887272
    # @return [Integer] the maximum tick supported by Uniswap V3
    MAX_TICK = 887272
    # @return [BigDecimal] the minimum sqrt ratio (Q64.96) corresponding to MIN_TICK
    MIN_SQRT_RATIO = BigDecimal("4295128739")
    # @return [BigDecimal] the maximum sqrt ratio (Q64.96) corresponding to MAX_TICK
    MAX_SQRT_RATIO = BigDecimal("1461446703485210103287273052203988822378723970342")

    # @return [BigDecimal] 2^96, the Q96 fixed-point scaling factor
    Q96 = BigDecimal(2**96)
    # @return [BigDecimal] 2^192
    Q192 = BigDecimal(2**192)

    class << self
      # Convert a tick index to its corresponding sqrt price in Q64.96 format.
      #
      # @param tick [Integer] the tick index (must be between MIN_TICK and MAX_TICK)
      # @return [Integer] the sqrt price as a Q64.96 fixed-point integer
      # @raise [ArgumentError] if tick is outside the valid range
      #
      # @example
      #   Uniswap::TickMath.get_sqrt_ratio_at_tick(0)
      #   #=> 79228162514264337593543950336
      def get_sqrt_ratio_at_tick(tick)
        raise ArgumentError, "Tick out of range" if tick < MIN_TICK || tick > MAX_TICK

        # sqrt(1.0001^tick) = 1.0001^(tick/2)
        sqrt_price = BigDecimal("1.0001") ** (BigDecimal(tick) / 2)
        (sqrt_price * Q96).floor
      end

      # Convert a Q64.96 sqrt price back to the nearest tick index (floored).
      #
      # @param sqrt_ratio_x96 [Integer, String] the sqrt price in Q64.96 format
      # @return [Integer] the tick index (floored)
      #
      # @example
      #   Uniswap::TickMath.get_tick_at_sqrt_ratio(79228162514264337593543950336)
      #   #=> 0
      def get_tick_at_sqrt_ratio(sqrt_ratio_x96)
        sqrt_price = BigDecimal(sqrt_ratio_x96) / Q96
        # tick = log(price) / log(1.0001) = 2 * log(sqrt_price) / log(1.0001)
        (2 * Math.log(sqrt_price.to_f) / Math.log(1.0001)).floor
      end

      # Convert a tick index to a human-readable price (token1 per token0),
      # adjusted for token decimal differences.
      #
      # @param tick [Integer] the tick index
      # @param token0_decimals [Integer] decimals of the base token (default: 18)
      # @param token1_decimals [Integer] decimals of the quote token (default: 18)
      # @return [BigDecimal] the price of token0 denominated in token1
      #
      # @example ETH/USDC price at tick 200000 (WETH=18 decimals, USDC=6)
      #   Uniswap::TickMath.tick_to_price(200000, token0_decimals: 18, token1_decimals: 6)
      def tick_to_price(tick, token0_decimals: 18, token1_decimals: 18)
        raw_price = BigDecimal("1.0001") ** tick
        # Adjust for decimal difference
        decimal_adjustment = BigDecimal(10) ** (token0_decimals - token1_decimals)
        raw_price * decimal_adjustment
      end

      # Convert a human-readable price to the nearest tick index (floored),
      # adjusting for token decimal differences.
      #
      # @param price [Numeric, String] the price of token0 in token1
      # @param token0_decimals [Integer] decimals of the base token (default: 18)
      # @param token1_decimals [Integer] decimals of the quote token (default: 18)
      # @return [Integer] the tick index (floored)
      def price_to_tick(price, token0_decimals: 18, token1_decimals: 18)
        decimal_adjustment = BigDecimal(10) ** (token0_decimals - token1_decimals)
        adjusted_price = BigDecimal(price.to_s) / decimal_adjustment
        (Math.log(adjusted_price.to_f) / Math.log(1.0001)).floor
      end

      # Convert a human-readable price to a Q64.96 sqrt price.
      #
      # @param price [Numeric, String] the price of token0 in token1
      # @param token0_decimals [Integer] decimals of the base token (default: 18)
      # @param token1_decimals [Integer] decimals of the quote token (default: 18)
      # @return [Integer] the sqrt price in Q64.96 fixed-point format
      def price_to_sqrt_price_x96(price, token0_decimals: 18, token1_decimals: 18)
        decimal_adjustment = BigDecimal(10) ** (token0_decimals - token1_decimals)
        adjusted_price = BigDecimal(price.to_s) / decimal_adjustment
        sqrt_price = Math.sqrt(adjusted_price.to_f)
        (BigDecimal(sqrt_price.to_s) * Q96).floor
      end

      # Convert a Q64.96 sqrt price to a human-readable price,
      # adjusted for token decimal differences.
      #
      # @param sqrt_price_x96 [Integer, String] the sqrt price in Q64.96 format
      # @param token0_decimals [Integer] decimals of the base token (default: 18)
      # @param token1_decimals [Integer] decimals of the quote token (default: 18)
      # @return [BigDecimal] the price of token0 denominated in token1
      def sqrt_price_x96_to_price(sqrt_price_x96, token0_decimals: 18, token1_decimals: 18)
        sqrt_price = BigDecimal(sqrt_price_x96) / Q96
        raw_price = sqrt_price ** 2
        decimal_adjustment = BigDecimal(10) ** (token0_decimals - token1_decimals)
        raw_price * decimal_adjustment
      end
    end
  end
end
