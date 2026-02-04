require "test_helper"

class Uniswap::LiquidityMathTest < ActiveSupport::TestCase
  test "get_token0_amount returns zero when price is above range" do
    # When current price is above the upper tick, position is all token1
    sqrt_price_current = Uniswap::TickMath.get_sqrt_ratio_at_tick(10000)
    sqrt_price_lower = Uniswap::TickMath.get_sqrt_ratio_at_tick(0)
    sqrt_price_upper = Uniswap::TickMath.get_sqrt_ratio_at_tick(5000)

    amount = Uniswap::LiquidityMath.get_token0_amount(
      liquidity: "1000000000000000000",
      sqrt_price_current: sqrt_price_current,
      sqrt_price_lower: sqrt_price_lower,
      sqrt_price_upper: sqrt_price_upper
    )

    assert_equal 0, amount.to_f
  end

  test "get_token1_amount returns zero when price is below range" do
    # When current price is below the lower tick, position is all token0
    sqrt_price_current = Uniswap::TickMath.get_sqrt_ratio_at_tick(-5000)
    sqrt_price_lower = Uniswap::TickMath.get_sqrt_ratio_at_tick(0)
    sqrt_price_upper = Uniswap::TickMath.get_sqrt_ratio_at_tick(5000)

    amount = Uniswap::LiquidityMath.get_token1_amount(
      liquidity: "1000000000000000000",
      sqrt_price_current: sqrt_price_current,
      sqrt_price_lower: sqrt_price_lower,
      sqrt_price_upper: sqrt_price_upper
    )

    assert_equal 0, amount.to_f
  end

  test "get_amounts returns both tokens when price is in range" do
    # Price in the middle of the range
    sqrt_price_current = Uniswap::TickMath.get_sqrt_ratio_at_tick(2500)
    sqrt_price_lower = Uniswap::TickMath.get_sqrt_ratio_at_tick(0)
    sqrt_price_upper = Uniswap::TickMath.get_sqrt_ratio_at_tick(5000)

    token0 = Uniswap::LiquidityMath.get_token0_amount(
      liquidity: "1000000000000000000",
      sqrt_price_current: sqrt_price_current,
      sqrt_price_lower: sqrt_price_lower,
      sqrt_price_upper: sqrt_price_upper
    )

    token1 = Uniswap::LiquidityMath.get_token1_amount(
      liquidity: "1000000000000000000",
      sqrt_price_current: sqrt_price_current,
      sqrt_price_lower: sqrt_price_lower,
      sqrt_price_upper: sqrt_price_upper
    )

    assert token0 > 0
    assert token1 > 0
  end

  test "get_amounts convenience method returns hash" do
    amounts = Uniswap::LiquidityMath.get_amounts(
      liquidity: "1000000000000000000",
      current_tick: 2500,
      tick_lower: 0,
      tick_upper: 5000
    )

    assert amounts.key?(:token0)
    assert amounts.key?(:token1)
    assert amounts[:token0] > 0
    assert amounts[:token1] > 0
  end

  test "respects token decimals" do
    # Same liquidity should give different raw amounts for different decimals
    amounts_18 = Uniswap::LiquidityMath.get_amounts(
      liquidity: "1000000000000000000000",
      current_tick: 0,
      tick_lower: -1000,
      tick_upper: 1000,
      token0_decimals: 18,
      token1_decimals: 18
    )

    amounts_6 = Uniswap::LiquidityMath.get_amounts(
      liquidity: "1000000000000000000000",
      current_tick: 0,
      tick_lower: -1000,
      tick_upper: 1000,
      token0_decimals: 6,
      token1_decimals: 18
    )

    # token0 with 6 decimals should be much larger number than with 18
    assert amounts_6[:token0] > amounts_18[:token0]
  end

  test "calculates from position data hash" do
    position_data = {
      "liquidity" => "1000000000000000000",
      "tickLower" => { "tickIdx" => "0" },
      "tickUpper" => { "tickIdx" => "5000" },
      "pool" => { "tick" => "2500" },
      "token0" => { "decimals" => "18" },
      "token1" => { "decimals" => "18" }
    }

    amounts = Uniswap::LiquidityMath.calculate_from_position_data(position_data)

    assert amounts.key?(:token0)
    assert amounts.key?(:token1)
  end
end
