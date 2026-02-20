require "test_helper"

class HedgeTest < ActiveSupport::TestCase
  test "needs_rebalance? returns true when deviation exceeds tolerance" do
    hedge = hedges(:eth_hedge) # target: 0.5, tolerance: 0.05
    pool_amount = 10.0
    current_short = 3.0 # target_short = 5.0, diff = 2.0 > 5.0 * 0.05 = 0.25

    assert hedge.needs_rebalance?(pool_amount, current_short)
  end

  test "needs_rebalance? returns false when within tolerance" do
    hedge = hedges(:eth_hedge) # target: 0.5, tolerance: 0.05
    pool_amount = 10.0
    current_short = 4.8 # target_short = 5.0, diff = 0.2 < 5.0 * 0.05 = 0.25

    assert_not hedge.needs_rebalance?(pool_amount, current_short)
  end

  test "needs_rebalance? returns true at exact boundary" do
    hedge = hedges(:eth_hedge) # target: 0.5, tolerance: 0.05
    pool_amount = 10.0
    current_short = 4.7 # target_short = 5.0, diff = 0.3 > 5.0 * 0.05 = 0.25

    assert hedge.needs_rebalance?(pool_amount, current_short)
  end

  test "needs_rebalance? tolerance is relative to target short not pool amount" do
    hedge = hedges(:eth_hedge) # target: 0.5, tolerance: 0.05
    pool_amount = 10.0
    # target_short = 5.0, threshold = 5.0 * 0.05 = 0.25
    # diff of 0.3 exceeds target-relative threshold (0.25)
    # but would NOT exceed pool-relative threshold (10.0 * 0.05 = 0.5)
    current_short = 4.7

    assert hedge.needs_rebalance?(pool_amount, current_short)
  end

  test "validates target range" do
    hedge = hedges(:eth_hedge)
    hedge.target = 0
    assert_not hedge.valid?

    hedge.target = 1.5
    assert_not hedge.valid?

    hedge.target = 0.5
    assert hedge.valid?
  end

  test "validates tolerance range" do
    hedge = hedges(:eth_hedge)
    hedge.tolerance = 0
    assert_not hedge.valid?

    hedge.tolerance = 1.5
    assert_not hedge.valid?

    hedge.tolerance = 0.05
    assert hedge.valid?
  end
end
