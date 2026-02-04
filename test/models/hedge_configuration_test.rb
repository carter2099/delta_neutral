require "test_helper"

class HedgeConfigurationTest < ActiveSupport::TestCase
  setup do
    @config = hedge_configurations(:eth_usdc_config)
  end

  test "valid hedge configuration" do
    assert @config.valid?
  end

  test "validates hedge_ratio in range" do
    @config.hedge_ratio = 0
    refute @config.valid?

    @config.hedge_ratio = 2.5
    refute @config.valid?

    @config.hedge_ratio = 1.0
    assert @config.valid?
  end

  test "validates rebalance_threshold in range" do
    @config.rebalance_threshold = 0
    refute @config.valid?

    @config.rebalance_threshold = 1.5
    refute @config.valid?

    @config.rebalance_threshold = 0.05
    assert @config.valid?
  end

  test "mapping_for returns configured mapping" do
    @config.token_mappings = { "WETH" => "ETH" }
    assert_equal "ETH", @config.mapping_for("WETH")
  end

  test "mapping_for uses default when not configured" do
    @config.token_mappings = {}
    assert_equal "ETH", @config.mapping_for("WETH")
    assert_equal "BTC", @config.mapping_for("WBTC")
  end

  test "mapping_for returns nil for stablecoins" do
    assert_nil @config.mapping_for("USDC")
    assert_nil @config.mapping_for("USDT")
    assert_nil @config.mapping_for("DAI")
  end

  test "mapping_for is case insensitive" do
    @config.token_mappings = { "WETH" => "ETH" }
    assert_equal "ETH", @config.mapping_for("weth")
    assert_equal "ETH", @config.mapping_for("Weth")
  end

  test "should_hedge? returns true for mapped tokens" do
    @config.token_mappings = { "WETH" => "ETH" }
    assert @config.should_hedge?("WETH")
  end

  test "should_hedge? returns false for unmapped tokens" do
    @config.token_mappings = { "USDC" => nil }
    refute @config.should_hedge?("USDC")
  end

  test "set_mapping updates token_mappings" do
    @config.set_mapping("LINK", "LINK")
    assert_equal "LINK", @config.token_mappings["LINK"]
  end

  test "target_hedge_for calculates negative size" do
    @config.token_mappings = { "WETH" => "ETH" }
    @config.hedge_ratio = 1.0

    target = @config.target_hedge_for("WETH", 10.0)

    assert_equal "ETH", target[:asset]
    assert_equal(-10.0, target[:size])
  end

  test "target_hedge_for respects hedge_ratio" do
    @config.token_mappings = { "WETH" => "ETH" }
    @config.hedge_ratio = 0.5

    target = @config.target_hedge_for("WETH", 10.0)

    assert_equal(-5.0, target[:size])
  end

  test "target_hedge_for returns nil for unhedged tokens" do
    target = @config.target_hedge_for("USDC", 1000.0)
    assert_nil target
  end
end
