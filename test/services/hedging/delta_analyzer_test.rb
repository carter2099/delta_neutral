require "test_helper"

class Hedging::DeltaAnalyzerTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @position = @user.positions.create!(
      nft_id: "analyzer_test_#{SecureRandom.hex(4)}",
      network: "ethereum",
      token0_symbol: "WETH",
      token1_symbol: "USDC",
      token0_amount: 10.0,
      token1_amount: 15000.0,
      token0_decimals: 18,
      token1_decimals: 6
    )
    @config = @position.hedge_configuration
    @config.update!(
      hedge_ratio: 1.0,
      rebalance_threshold: 0.05,
      token_mappings: { "WETH" => "ETH", "USDC" => nil }
    )
    @analyzer = Hedging::DeltaAnalyzer.new
  end

  test "analyze returns needs_rebalance false when within threshold" do
    # Create hedge that's very close to target (-10)
    @position.hedge_positions.create!(
      asset: "ETH",
      size: -9.8,
      entry_price: 2000.0
    )

    result = @analyzer.analyze(@position)

    refute result.needs_rebalance
    assert result.drift_percent < 0.05
  end

  test "analyze returns needs_rebalance true when exceeds threshold" do
    # Create hedge that's far from target (-10)
    @position.hedge_positions.create!(
      asset: "ETH",
      size: -8.0,
      entry_price: 2000.0
    )

    result = @analyzer.analyze(@position)

    assert result.needs_rebalance
    assert result.drift_percent >= 0.05
    assert_includes result.reason, "exceeds threshold"
  end

  test "analyze returns needs_rebalance true when no hedge exists" do
    result = @analyzer.analyze(@position)

    assert result.needs_rebalance
    assert_equal 1.0, result.drift_percent
  end

  test "analyze returns adjustments in result" do
    @position.hedge_positions.create!(
      asset: "ETH",
      size: -8.0,
      entry_price: 2000.0
    )

    result = @analyzer.analyze(@position)

    assert result.adjustments.any?
    eth_adj = result.adjustments.find { |a| a[:asset] == "ETH" }
    assert_not_nil eth_adj
  end

  test "analyze handles position without config" do
    @position.hedge_configuration.destroy
    @position.reload

    result = @analyzer.analyze(@position)

    refute result.needs_rebalance
    assert_includes result.reason, "No hedge configuration"
  end

  test "positions_needing_rebalance filters correctly" do
    # Create another position that's balanced
    other_position = @user.positions.create!(
      nft_id: "balanced_test_#{SecureRandom.hex(4)}",
      network: "ethereum",
      token0_symbol: "LINK",
      token1_symbol: "USDC",
      token0_amount: 100.0,
      token1_amount: 1000.0
    )
    other_position.hedge_configuration.update!(
      token_mappings: { "LINK" => "LINK", "USDC" => nil }
    )
    other_position.hedge_positions.create!(
      asset: "LINK",
      size: -100.0,
      entry_price: 10.0
    )

    positions = [@position, other_position]
    needing_rebalance = @analyzer.positions_needing_rebalance(positions)

    assert_includes needing_rebalance, @position
    refute_includes needing_rebalance, other_position
  end
end
