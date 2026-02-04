require "test_helper"

class Uniswap::TickMathTest < ActiveSupport::TestCase
  test "tick_to_price converts tick 0 to price 1" do
    price = Uniswap::TickMath.tick_to_price(0)
    assert_in_delta 1.0, price.to_f, 0.0001
  end

  test "tick_to_price handles positive ticks" do
    # tick 1000 should give price > 1
    price = Uniswap::TickMath.tick_to_price(1000)
    assert price > 1
  end

  test "tick_to_price handles negative ticks" do
    # tick -1000 should give price < 1
    price = Uniswap::TickMath.tick_to_price(-1000)
    assert price < 1
  end

  test "tick_to_price adjusts for decimal differences" do
    # Different decimals should affect the price calculation
    price_same = Uniswap::TickMath.tick_to_price(10000, token0_decimals: 18, token1_decimals: 18)
    price_diff = Uniswap::TickMath.tick_to_price(10000, token0_decimals: 6, token1_decimals: 18)

    # With token0 having fewer decimals, the adjustment multiplies by 10^(6-18) = 10^-12
    # So price_diff should be much smaller than price_same
    assert price_diff < price_same
  end

  test "price_to_tick is inverse of tick_to_price" do
    original_tick = 5000
    price = Uniswap::TickMath.tick_to_price(original_tick)
    recovered_tick = Uniswap::TickMath.price_to_tick(price)
    assert_in_delta original_tick, recovered_tick, 1
  end

  test "get_sqrt_ratio_at_tick returns valid Q96 value" do
    sqrt_ratio = Uniswap::TickMath.get_sqrt_ratio_at_tick(0)
    expected = BigDecimal(2**96)  # sqrt(1) * 2^96 = 2^96
    assert_in_delta expected.to_f, sqrt_ratio.to_f, expected.to_f * 0.0001
  end

  test "get_tick_at_sqrt_ratio is inverse of get_sqrt_ratio_at_tick" do
    original_tick = 10000
    sqrt_ratio = Uniswap::TickMath.get_sqrt_ratio_at_tick(original_tick)
    recovered_tick = Uniswap::TickMath.get_tick_at_sqrt_ratio(sqrt_ratio)
    assert_in_delta original_tick, recovered_tick, 1
  end

  test "raises error for tick out of range" do
    assert_raises ArgumentError do
      Uniswap::TickMath.get_sqrt_ratio_at_tick(Uniswap::TickMath::MAX_TICK + 1)
    end

    assert_raises ArgumentError do
      Uniswap::TickMath.get_sqrt_ratio_at_tick(Uniswap::TickMath::MIN_TICK - 1)
    end
  end

  test "sqrt_price_x96_to_price and price_to_sqrt_price_x96 are inverses" do
    original_price = 1500.0
    sqrt_price = Uniswap::TickMath.price_to_sqrt_price_x96(original_price)
    recovered_price = Uniswap::TickMath.sqrt_price_x96_to_price(sqrt_price)
    assert_in_delta original_price, recovered_price.to_f, 1.0
  end
end
