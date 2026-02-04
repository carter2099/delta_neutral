require "test_helper"

class Hedging::CalculatorTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @position = @user.positions.create!(
      nft_id: "calc_test_#{SecureRandom.hex(4)}",
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
      token_mappings: { "WETH" => "ETH", "USDC" => nil }
    )
    @calculator = Hedging::Calculator.new
  end

  test "calculate_targets returns targets for hedgeable tokens" do
    targets = @calculator.calculate_targets(@position)

    assert targets.key?("ETH")
    assert_equal "ETH", targets["ETH"][:asset]
    assert_in_delta(-10.0, targets["ETH"][:target_size], 0.001)
  end

  test "calculate_targets respects hedge_ratio" do
    @config.update!(hedge_ratio: 0.5)

    targets = @calculator.calculate_targets(@position)

    assert_in_delta(-5.0, targets["ETH"][:target_size], 0.001)
  end

  test "calculate_targets skips tokens with nil mapping" do
    targets = @calculator.calculate_targets(@position)

    # USDC is mapped to nil, should not appear
    refute targets.values.any? { |t| t[:source_token] == "USDC" }
  end

  test "calculate_targets combines same HL symbol" do
    # If both tokens map to same symbol, they should be combined
    @position.update!(token1_symbol: "WETH", token1_amount: 5.0)
    @config.update!(token_mappings: { "WETH" => "ETH" })

    targets = @calculator.calculate_targets(@position)

    assert_equal 1, targets.size
    assert_in_delta(-15.0, targets["ETH"][:target_size], 0.001)
  end

  test "calculate_adjustments returns delta from current to target" do
    # Create existing hedge position
    @position.hedge_positions.create!(
      asset: "ETH",
      size: -8.0,
      entry_price: 2000.0
    )

    adjustments = @calculator.calculate_adjustments(@position)

    eth_adj = adjustments.find { |a| a[:asset] == "ETH" }
    assert_not_nil eth_adj
    assert_in_delta(-8.0, eth_adj[:current_size], 0.001)
    assert_in_delta(-10.0, eth_adj[:target_size], 0.001)
    assert_in_delta(-2.0, eth_adj[:delta], 0.001)
  end

  test "calculate_adjustments marks positions for closure if not in targets" do
    # Create hedge position for asset no longer needed
    @position.hedge_positions.create!(
      asset: "BTC",
      size: -0.5,
      entry_price: 50000.0
    )

    adjustments = @calculator.calculate_adjustments(@position)

    btc_adj = adjustments.find { |a| a[:asset] == "BTC" }
    assert_not_nil btc_adj
    assert_equal 0, btc_adj[:target_size]
    assert_equal :close, btc_adj[:action]
  end

  test "calculate_adjustments handles new positions" do
    # No existing hedge
    adjustments = @calculator.calculate_adjustments(@position)

    eth_adj = adjustments.find { |a| a[:asset] == "ETH" }
    assert_not_nil eth_adj
    assert_equal 0, eth_adj[:current_size]
    assert_in_delta(-10.0, eth_adj[:target_size], 0.001)
  end
end
