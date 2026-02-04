require "test_helper"

class PositionTest < ActiveSupport::TestCase
  setup do
    @position = positions(:eth_usdc)
  end

  test "valid position" do
    assert @position.valid?
  end

  test "requires nft_id" do
    @position.nft_id = nil
    refute @position.valid?
  end

  test "requires network" do
    @position.network = nil
    refute @position.valid?
  end

  test "validates network inclusion" do
    @position.network = "invalid"
    refute @position.valid?

    @position.network = "ethereum"
    assert @position.valid?

    @position.network = "arbitrum"
    assert @position.valid?
  end

  test "enforces unique nft_id per user per network" do
    duplicate = @position.user.positions.build(
      nft_id: @position.nft_id,
      network: @position.network
    )
    refute duplicate.valid?
    assert duplicate.errors[:nft_id].any?
  end

  test "allows same nft_id on different network" do
    new_position = @position.user.positions.build(
      nft_id: @position.nft_id,
      network: "arbitrum"
    )
    assert new_position.valid?
  end

  test "creates hedge_configuration after create" do
    user = users(:one)
    position = user.positions.create!(
      nft_id: "new_nft",
      network: "ethereum"
    )
    assert position.hedge_configuration.present?
  end

  test "total_value_usd calculates correctly" do
    expected = (10.0 * 2000.0) + (15000.0 * 1.0)
    assert_in_delta expected, @position.total_value_usd, 0.01
  end

  test "lp_delta_usd calculates correctly" do
    current = @position.total_value_usd
    initial = @position.initial_value_usd
    assert_in_delta(current - initial, @position.lp_delta_usd, 0.01)
  end

  test "in_range? returns true when tick in range" do
    @position.current_tick = 0
    @position.tick_lower = -100000
    @position.tick_upper = 100000
    assert @position.in_range?
  end

  test "in_range? returns false when tick below range" do
    @position.current_tick = -200000
    refute @position.in_range?
  end

  test "in_range? returns false when tick above range" do
    @position.current_tick = 200000
    refute @position.in_range?
  end

  test "active scope returns only active positions" do
    assert_includes Position.active, @position

    @position.update!(active: false)
    refute_includes Position.active, @position
  end

  test "subgraph_url returns correct URL for network" do
    assert_includes @position.subgraph_url, "thegraph.com"

    @position.network = "arbitrum"
    assert_includes @position.subgraph_url, "thegraph.com"
  end

  test "total_realized_pnl sums realized_pnls" do
    total = @position.realized_pnls.sum(:realized_pnl)
    assert_equal total, @position.total_realized_pnl
  end
end
