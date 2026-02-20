require "test_helper"

class HedgeSyncJobTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    ENV["HYPERLIQUID_PRIVATE_KEY"] ||= "0xtest"
    ENV["HYPERLIQUID_WALLET_ADDRESS"] ||= "0xwallet"
    ENV["HYPERLIQUID_TESTNET"] ||= "true"
  end

  private

  def build_mock_service(positions:, fills: [], fills_error: nil)
    user_state = {
      "assetPositions" => positions.map do |p|
        { "position" => { "coin" => p[:coin], "szi" => p[:szi],
                          "entryPx" => "2000", "unrealizedPnl" => "-10",
                          "returnOnEquity" => "-0.01", "liquidationPx" => nil } }
      end,
      "marginSummary" => { "accountValue" => "10000" }
    }

    service = HyperliquidService.new(private_key: "0xtest", wallet_address: "0xwallet", testnet: true)

    meta = {
      "universe" => [
        { "name" => "ETH", "szDecimals" => 4 },
        { "name" => "BTC", "szDecimals" => 5 },
        { "name" => "USDC", "szDecimals" => 2 }
      ]
    }

    mock_info = Object.new
    mock_info.define_singleton_method(:user_state) { |_| user_state }
    mock_info.define_singleton_method(:meta) { meta }
    if fills_error
      mock_info.define_singleton_method(:user_fills_by_time) { |_addr, _start_time| raise fills_error }
    else
      mock_info.define_singleton_method(:user_fills_by_time) { |_addr, _start_time| fills }
    end

    mock_exchange = Object.new
    mock_exchange.define_singleton_method(:market_close) { |**_| { "status" => "ok" } }
    mock_exchange.define_singleton_method(:market_order) { |**_| { "status" => "ok" } }
    mock_exchange.define_singleton_method(:update_leverage) { |**_| { "status" => "ok" } }

    mock_sdk = Object.new
    mock_sdk.define_singleton_method(:info) { mock_info }
    mock_sdk.define_singleton_method(:exchange) { mock_exchange }

    service.instance_variable_set(:@sdk, mock_sdk)
    service
  end

  public

  test "enqueues job without error" do
    assert_nothing_raised do
      HedgeSyncJob.perform_later
    end
  end

  test "creates rebalance records with realized PnL from fills" do
    hedge = hedges(:eth_hedge)

    close_fills = [
      { "coin" => "ETH", "closedPnl" => "-8.50", "px" => "2010", "sz" => "0.3", "side" => "B", "time" => Time.current.to_i * 1000 }
    ]

    mock_service = build_mock_service(
      positions: [ { coin: "ETH", szi: "-0.3" } ],
      fills: close_fills
    )

    assert_difference "ShortRebalance.count", 2 do
      HyperliquidService.stub(:new, mock_service) do
        HedgeSyncJob.perform_now(hedge.id)
      end
    end

    weth_rebalance = ShortRebalance.where(asset: "WETH").order(:id).last
    assert_equal BigDecimal("-8.50"), weth_rebalance.realized_pnl
  end

  test "realized PnL defaults to zero when fills fetch fails" do
    hedge = hedges(:eth_hedge)

    mock_service = build_mock_service(
      positions: [ { coin: "ETH", szi: "-0.3" } ],
      fills_error: Hyperliquid::NetworkError.new("connection refused")
    )

    assert_difference "ShortRebalance.count", 2 do
      HyperliquidService.stub(:new, mock_service) do
        HedgeSyncJob.perform_now(hedge.id)
      end
    end

    weth_rebalance = ShortRebalance.where(asset: "WETH").order(:id).last
    assert_equal BigDecimal("0"), weth_rebalance.realized_pnl
  end

  test "closes over-hedged short and notifies when pool amount is zero" do
    hedge = hedges(:eth_hedge)
    # Both pool amounts zero: position is fully out of range on both sides.
    # WETH has an open short (over-hedged); USDC has none (nothing to close).
    # Only the WETH asset produces a rebalance record; hedge stays active so
    # the sibling short and future re-entries are handled normally.
    hedge.position.update!(asset0_amount: BigDecimal("0"), asset1_amount: BigDecimal("0"))

    close_fills = [
      { "coin" => "ETH", "closedPnl" => "-12.00", "px" => "1900", "sz" => "0.5", "side" => "B", "time" => Time.current.to_i * 1000 }
    ]

    mock_service = build_mock_service(
      positions: [ { coin: "ETH", szi: "-0.5" } ],
      fills: close_fills
    )

    assert_emails 1 do
      assert_difference "ShortRebalance.count", 1 do
        HyperliquidService.stub(:new, mock_service) do
          HedgeSyncJob.perform_now(hedge.id)
        end
      end
    end

    rebalance = ShortRebalance.where(asset: "WETH").order(:id).last
    assert_equal BigDecimal("0.5"), rebalance.old_short_size
    assert_equal BigDecimal("0"), rebalance.new_short_size
    assert_equal BigDecimal("-12.00"), rebalance.realized_pnl

    hedge.reload
    assert hedge.active?, "hedge should remain active to manage sibling asset and handle re-entry"
  end
end
