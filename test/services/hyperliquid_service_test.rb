require "test_helper"

class HyperliquidServiceTest < ActiveSupport::TestCase
  include ServiceStubs

  setup do
    @service = HyperliquidService.new(
      private_key: "0xtest",
      wallet_address: "0xwallet",
      testnet: true
    )
  end

  test "get_positions parses user state" do
    user_state = stub_hyperliquid_user_state(
      positions: [
        { asset: "ETH", size: "-0.5", entry_price: "2000", unrealized_pnl: "-50" }
      ]
    )

    mock_info = Object.new
    mock_info.define_singleton_method(:user_state) { |_addr| user_state }
    mock_sdk = Object.new
    mock_sdk.define_singleton_method(:info) { mock_info }
    @service.instance_variable_set(:@sdk, mock_sdk)

    positions = @service.get_positions
    assert_equal 1, positions.length
    assert_equal "ETH", positions.first[:asset]
    assert_equal BigDecimal("-0.5"), positions.first[:size]
    assert_equal BigDecimal("-50"), positions.first[:unrealized_pnl]
  end

  test "get_positions with address queries that address" do
    queried_address = nil
    user_state = stub_hyperliquid_user_state(positions: [])

    mock_info = Object.new
    mock_info.define_singleton_method(:user_state) { |addr| queried_address = addr; user_state }
    mock_sdk = Object.new
    mock_sdk.define_singleton_method(:info) { mock_info }
    @service.instance_variable_set(:@sdk, mock_sdk)

    @service.get_positions(address: "0xsubaccount")
    assert_equal "0xsubaccount", queried_address
  end

  test "get_position returns specific asset" do
    user_state = stub_hyperliquid_user_state(
      positions: [
        { asset: "ETH", size: "-0.5", entry_price: "2000" },
        { asset: "BTC", size: "-0.1", entry_price: "50000" }
      ]
    )

    mock_info = Object.new
    mock_info.define_singleton_method(:user_state) { |_addr| user_state }
    mock_sdk = Object.new
    mock_sdk.define_singleton_method(:info) { mock_info }
    @service.instance_variable_set(:@sdk, mock_sdk)

    pos = @service.get_position("BTC")
    assert_equal "BTC", pos[:asset]
    assert_equal BigDecimal("-0.1"), pos[:size]
  end

  test "open_short calls market_order with numeric size" do
    called_with = nil
    mock_exchange = Object.new
    mock_exchange.define_singleton_method(:market_order) { |**args| called_with = args; { "status" => "ok" } }
    mock_sdk = Object.new
    mock_sdk.define_singleton_method(:exchange) { mock_exchange }
    @service.instance_variable_set(:@sdk, mock_sdk)

    @service.open_short(asset: "ETH", size: 0.5)
    assert_equal "ETH", called_with[:coin]
    assert_equal false, called_with[:is_buy]
    assert_equal 0.5, called_with[:size]
    assert_nil called_with[:vault_address]
  end

  test "open_short passes vault_address when provided" do
    called_with = nil
    mock_exchange = Object.new
    mock_exchange.define_singleton_method(:market_order) { |**args| called_with = args; { "status" => "ok" } }
    mock_sdk = Object.new
    mock_sdk.define_singleton_method(:exchange) { mock_exchange }
    @service.instance_variable_set(:@sdk, mock_sdk)

    @service.open_short(asset: "ETH", size: 0.5, vault_address: "0xsub1")
    assert_equal "0xsub1", called_with[:vault_address]
  end

  test "close_short calls market_close" do
    called_with = nil
    mock_exchange = Object.new
    mock_exchange.define_singleton_method(:market_close) { |**args| called_with = args; { "status" => "ok" } }
    mock_sdk = Object.new
    mock_sdk.define_singleton_method(:exchange) { mock_exchange }
    @service.instance_variable_set(:@sdk, mock_sdk)

    @service.close_short(asset: "ETH")
    assert_equal "ETH", called_with[:coin]
    assert_nil called_with[:size]
    assert_nil called_with[:vault_address]
  end

  test "close_short passes vault_address when provided" do
    called_with = nil
    mock_exchange = Object.new
    mock_exchange.define_singleton_method(:market_close) { |**args| called_with = args; { "status" => "ok" } }
    mock_sdk = Object.new
    mock_sdk.define_singleton_method(:exchange) { mock_exchange }
    @service.instance_variable_set(:@sdk, mock_sdk)

    @service.close_short(asset: "ETH", vault_address: "0xsub1")
    assert_equal "0xsub1", called_with[:vault_address]
  end

  test "close_short with size passes size through" do
    called_with = nil
    mock_exchange = Object.new
    mock_exchange.define_singleton_method(:market_close) { |**args| called_with = args; { "status" => "ok" } }
    mock_sdk = Object.new
    mock_sdk.define_singleton_method(:exchange) { mock_exchange }
    @service.instance_variable_set(:@sdk, mock_sdk)

    @service.close_short(asset: "ETH", size: 0.3)
    assert_equal "ETH", called_with[:coin]
    assert_equal 0.3, called_with[:size]
  end

  test "close_short handles no open position gracefully" do
    mock_exchange = Object.new
    mock_exchange.define_singleton_method(:market_close) { |**_| raise ArgumentError, "No open position found for ETH" }
    mock_sdk = Object.new
    mock_sdk.define_singleton_method(:exchange) { mock_exchange }
    @service.instance_variable_set(:@sdk, mock_sdk)

    result = @service.close_short(asset: "ETH")
    assert_nil result
  end

  test "close_short re-raises non-position ArgumentErrors" do
    mock_exchange = Object.new
    mock_exchange.define_singleton_method(:market_close) { |**_| raise ArgumentError, "Unknown asset: FOO" }
    mock_sdk = Object.new
    mock_sdk.define_singleton_method(:exchange) { mock_exchange }
    @service.instance_variable_set(:@sdk, mock_sdk)

    assert_raises(ArgumentError) { @service.close_short(asset: "FOO") }
  end

  test "set_leverage passes vault_address when provided" do
    called_with = nil
    mock_exchange = Object.new
    mock_exchange.define_singleton_method(:update_leverage) { |**args| called_with = args; { "status" => "ok" } }
    mock_sdk = Object.new
    mock_sdk.define_singleton_method(:exchange) { mock_exchange }
    @service.instance_variable_set(:@sdk, mock_sdk)

    @service.set_leverage(asset: "ETH", leverage: 5, is_cross: true, vault_address: "0xsub1")
    assert_equal "0xsub1", called_with[:vault_address]
  end

  test "user_fills with start_time calls user_fills_by_time" do
    expected_fills = [ { "coin" => "ETH" } ]
    called_with = nil
    mock_info = Object.new
    mock_info.define_singleton_method(:user_fills_by_time) { |addr, time| called_with = { addr: addr, time: time }; expected_fills }
    mock_sdk = Object.new
    mock_sdk.define_singleton_method(:info) { mock_info }
    @service.instance_variable_set(:@sdk, mock_sdk)

    start = Time.new(2025, 1, 1, 0, 0, 0, "+00:00")
    fills = @service.user_fills(start_time: start)

    assert_equal expected_fills, fills
    assert_equal "0xwallet", called_with[:addr]
    assert_equal start.to_i * 1000, called_with[:time]
  end

  test "user_fills with address queries that address" do
    called_with = nil
    mock_info = Object.new
    mock_info.define_singleton_method(:user_fills_by_time) { |addr, time| called_with = { addr: addr, time: time }; [] }
    mock_sdk = Object.new
    mock_sdk.define_singleton_method(:info) { mock_info }
    @service.instance_variable_set(:@sdk, mock_sdk)

    @service.user_fills(start_time: Time.current, address: "0xsub1")
    assert_equal "0xsub1", called_with[:addr]
  end

  test "create_subaccount calls SDK" do
    called_with = nil
    mock_exchange = Object.new
    mock_exchange.define_singleton_method(:create_sub_account) { |**args| called_with = args; { "subAccountUser" => "0xnewsub" } }
    mock_sdk = Object.new
    mock_sdk.define_singleton_method(:exchange) { mock_exchange }
    @service.instance_variable_set(:@sdk, mock_sdk)

    result = @service.create_subaccount(name: "hedge-1-eth")
    assert_equal "hedge-1-eth", called_with[:name]
    assert_equal "0xnewsub", result["subAccountUser"]
  end

  test "transfer_to_subaccount calls SDK with is_deposit true" do
    called_with = nil
    mock_exchange = Object.new
    mock_exchange.define_singleton_method(:sub_account_transfer) { |**args| called_with = args; { "status" => "ok" } }
    mock_sdk = Object.new
    mock_sdk.define_singleton_method(:exchange) { mock_exchange }
    @service.instance_variable_set(:@sdk, mock_sdk)

    @service.transfer_to_subaccount(subaccount_address: "0xsub1", usd: 100)
    assert_equal "0xsub1", called_with[:sub_account_user]
    assert_equal true, called_with[:is_deposit]
    assert_equal 100, called_with[:usd]
  end

  test "withdraw_from_subaccount calls SDK with is_deposit false" do
    called_with = nil
    mock_exchange = Object.new
    mock_exchange.define_singleton_method(:sub_account_transfer) { |**args| called_with = args; { "status" => "ok" } }
    mock_sdk = Object.new
    mock_sdk.define_singleton_method(:exchange) { mock_exchange }
    @service.instance_variable_set(:@sdk, mock_sdk)

    @service.withdraw_from_subaccount(subaccount_address: "0xsub1", usd: 50)
    assert_equal "0xsub1", called_with[:sub_account_user]
    assert_equal false, called_with[:is_deposit]
    assert_equal 50, called_with[:usd]
  end

  test "list_subaccounts queries main wallet" do
    called_with = nil
    mock_info = Object.new
    mock_info.define_singleton_method(:user_subaccounts) { |addr| called_with = addr; [ { "subAccountUser" => "0xsub1" } ] }
    mock_sdk = Object.new
    mock_sdk.define_singleton_method(:info) { mock_info }
    @service.instance_variable_set(:@sdk, mock_sdk)

    result = @service.list_subaccounts
    assert_equal "0xwallet", called_with
    assert_equal 1, result.size
  end

  test "account_balance parses margin summary" do
    state = {
      "assetPositions" => [],
      "marginSummary" => { "accountValue" => "1500.50", "totalRawUsd" => "1200.00" }
    }
    mock_info = Object.new
    mock_info.define_singleton_method(:user_state) { |_| state }
    mock_sdk = Object.new
    mock_sdk.define_singleton_method(:info) { mock_info }
    @service.instance_variable_set(:@sdk, mock_sdk)

    balance = @service.account_balance("0xsub1")
    assert_equal BigDecimal("1200.00"), balance[:withdrawable]
    assert_equal BigDecimal("1500.50"), balance[:account_value]
  end
end
