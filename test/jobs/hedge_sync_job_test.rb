require "test_helper"

class HedgeSyncJobTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    ENV["HYPERLIQUID_PRIVATE_KEY"] ||= "0xtest"
    ENV["HYPERLIQUID_WALLET_ADDRESS"] ||= "0xwallet"
    ENV["HYPERLIQUID_TESTNET"] ||= "true"
  end

  private

  def build_mock_service(positions:, fills: [], fills_error: nil, subaccounts: [], subaccount_states: {})
    user_states = {}

    # Main account state
    user_states[nil] = build_user_state(positions)

    # Subaccount states
    subaccount_states.each do |addr, state|
      user_states[addr] = build_user_state(state[:positions] || [])
    end

    service = HyperliquidService.new(private_key: "0xtest", wallet_address: "0xwallet", testnet: true)

    meta = {
      "universe" => [
        { "name" => "ETH", "szDecimals" => 4 },
        { "name" => "BTC", "szDecimals" => 5 },
        { "name" => "USDC", "szDecimals" => 2 }
      ]
    }

    mock_info = Object.new
    mock_info.define_singleton_method(:user_state) do |addr|
      user_states[addr] || user_states[nil]
    end
    mock_info.define_singleton_method(:meta) { meta }
    mock_info.define_singleton_method(:user_subaccounts) { |_| subaccounts }
    if fills_error
      mock_info.define_singleton_method(:user_fills_by_time) { |_addr, _start_time| raise fills_error }
    else
      mock_info.define_singleton_method(:user_fills_by_time) { |_addr, _start_time| fills }
    end

    mock_exchange = Object.new
    mock_exchange.define_singleton_method(:market_close) { |**_| { "status" => "ok" } }
    mock_exchange.define_singleton_method(:market_order) { |**_| { "status" => "ok" } }
    mock_exchange.define_singleton_method(:update_leverage) { |**_| { "status" => "ok" } }
    mock_exchange.define_singleton_method(:create_sub_account) { |**_| { "subAccountUser" => "0xnewsub" } }
    mock_exchange.define_singleton_method(:sub_account_transfer) { |**_| { "status" => "ok" } }

    mock_sdk = Object.new
    mock_sdk.define_singleton_method(:info) { mock_info }
    mock_sdk.define_singleton_method(:exchange) { mock_exchange }

    service.instance_variable_set(:@sdk, mock_sdk)
    service
  end

  def build_user_state(positions)
    {
      "assetPositions" => positions.map do |p|
        { "position" => { "coin" => p[:coin], "szi" => p[:szi],
                          "entryPx" => "2000", "positionValue" => "1000",
                          "marginUsed" => "100", "unrealizedPnl" => "-10",
                          "returnOnEquity" => "-0.01", "liquidationPx" => nil } }
      end,
      "marginSummary" => { "accountValue" => "10000", "totalRawUsd" => "10000" }
    }
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

  test "allocates subaccount when main account is in use for same asset" do
    hedge = hedges(:eth_hedge)

    # Create a second position+hedge that also uses WETH, already on main account
    position2 = Position.create!(
      user: hedge.position.user,
      dex: hedge.position.dex,
      wallet: hedge.position.wallet,
      asset0: "WETH",
      asset1: "USDC",
      asset0_amount: "2.0",
      asset1_amount: "4000.0",
      asset0_price_usd: "2000.0",
      asset1_price_usd: "1.0",
      external_id: "99999",
      pool_address: "0xpool9999",
      active: true
    )
    hedge2 = Hedge.create!(
      position: position2,
      target: "0.5",
      tolerance: "0.05",
      active: true
    )
    # hedge2 has no hl_account columns set → it's on main for both assets
    # When hedge (eth_hedge) syncs, it should detect main is taken for ETH and allocate a subaccount

    mock_service = build_mock_service(
      positions: [],
      subaccounts: [ { "subAccountUser" => "0xexistingsub" } ]
    )

    HyperliquidService.stub(:new, mock_service) do
      HedgeSyncJob.perform_now(hedge.id)
    end

    hedge.reload
    assert_equal "0xexistingsub", hedge.asset0_hl_account
    # hedge2 also claims main for USDC (asset1), so hedge gets subaccount for both
    assert_equal "0xexistingsub", hedge.asset1_hl_account
  ensure
    hedge2&.destroy
    position2&.destroy
  end

  test "creates new subaccount when all existing subaccounts are in use" do
    hedge = hedges(:eth_hedge)

    # Another hedge already on main for ETH
    position2 = Position.create!(
      user: hedge.position.user,
      dex: hedge.position.dex,
      wallet: hedge.position.wallet,
      asset0: "WETH",
      asset1: "USDC",
      asset0_amount: "2.0",
      asset1_amount: "4000.0",
      asset0_price_usd: "2000.0",
      asset1_price_usd: "1.0",
      external_id: "88888",
      pool_address: "0xpool8888",
      active: true
    )
    hedge2 = Hedge.create!(position: position2, target: "0.5", tolerance: "0.05", active: true)

    # Third hedge on subaccount 0xsub1 for ETH
    position3 = Position.create!(
      user: hedge.position.user,
      dex: hedge.position.dex,
      wallet: hedge.position.wallet,
      asset0: "WETH",
      asset1: "USDC",
      asset0_amount: "1.0",
      asset1_amount: "2000.0",
      asset0_price_usd: "2000.0",
      asset1_price_usd: "1.0",
      external_id: "77777",
      pool_address: "0xpool7777",
      active: true
    )
    hedge3 = Hedge.create!(position: position3, target: "0.5", tolerance: "0.05", active: true, asset0_hl_account: "0xsub1")

    mock_service = build_mock_service(
      positions: [],
      subaccounts: [ { "subAccountUser" => "0xsub1" } ]
    )

    HyperliquidService.stub(:new, mock_service) do
      HedgeSyncJob.perform_now(hedge.id)
    end

    hedge.reload
    # 0xsub1 is taken by hedge3, main is taken by hedge2 → should create new
    assert_equal "0xnewsub", hedge.asset0_hl_account
  ensure
    hedge3&.destroy
    position3&.destroy
    hedge2&.destroy
    position2&.destroy
  end
end
