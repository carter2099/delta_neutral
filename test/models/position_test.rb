require "test_helper"

class PositionTest < ActiveSupport::TestCase
  test "total_value_usd calculates correctly" do
    position = positions(:eth_usdc)
    # 1.5 ETH * $2000 + 3000 USDC * $1 = $6000
    assert_equal BigDecimal("6000"), position.total_value_usd
  end

  test "active scope returns only active positions" do
    position = positions(:eth_usdc)
    assert_includes Position.active, position

    position.update!(active: false)
    assert_not_includes Position.active, position
  end
end
