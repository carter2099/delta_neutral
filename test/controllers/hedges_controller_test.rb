require "test_helper"

class HedgesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  test "should get show" do
    hedge = hedges(:eth_hedge)
    mock_service = Object.new
    mock_service.define_singleton_method(:get_position) { |_, **_| nil }
    mock_service.define_singleton_method(:sz_decimals) { |_| 6 }

    HyperliquidService.stub(:new, mock_service) do
      get hedge_path(hedge)
    end
    assert_response :success
  end

  test "should get new" do
    get new_hedge_path
    assert_response :success
  end

  test "should get edit" do
    hedge = hedges(:eth_hedge)
    get edit_hedge_path(hedge)
    assert_response :success
  end

  test "should update hedge" do
    hedge = hedges(:eth_hedge)
    patch hedge_path(hedge), params: { hedge: { target: 0.6, tolerance: 0.03 } }
    assert_redirected_to hedge_path(hedge)
    hedge.reload
    assert_equal BigDecimal("0.6"), hedge.target
  end

  test "should destroy hedge and close shorts" do
    hedge = hedges(:eth_hedge)

    mock_service = Object.new
    mock_service.define_singleton_method(:close_short) { |**_| nil }
    mock_service.define_singleton_method(:user_fills) { |**_| [] }

    HyperliquidService.stub(:new, mock_service) do
      assert_difference "Hedge.count", -1 do
        delete hedge_path(hedge)
      end
    end

    assert_redirected_to position_path(hedge.position)
  end

  test "should destroy hedge on subaccount and withdraw USDC" do
    hedge = hedges(:eth_hedge)
    hedge.update!(asset0_hl_account: "0xsub1")

    withdraw_called = false
    mock_service = Object.new
    mock_service.define_singleton_method(:close_short) { |**_| nil }
    mock_service.define_singleton_method(:user_fills) { |**_| [] }
    mock_service.define_singleton_method(:account_balance) { |_| { withdrawable: BigDecimal("500"), account_value: BigDecimal("500") } }
    mock_service.define_singleton_method(:withdraw_from_subaccount) { |**_| withdraw_called = true; { "status" => "ok" } }

    HyperliquidService.stub(:new, mock_service) do
      assert_difference "Hedge.count", -1 do
        delete hedge_path(hedge)
      end
    end

    assert withdraw_called, "should have withdrawn USDC from subaccount"
    assert_redirected_to position_path(hedge.position)
  end

  test "should not destroy hedge if hyperliquid fails" do
    hedge = hedges(:eth_hedge)

    failing_service = Object.new
    failing_service.define_singleton_method(:close_short) { |**_| raise "Connection refused" }

    HyperliquidService.stub(:new, failing_service) do
      assert_no_difference "Hedge.count" do
        delete hedge_path(hedge)
      end
    end

    assert_redirected_to hedge_path(hedge)
    assert_match(/Failed to close Hyperliquid shorts/, flash[:alert])
  end

  test "should queue sync_now" do
    hedge = hedges(:eth_hedge)
    post sync_now_hedge_path(hedge)
    assert_redirected_to hedge_path(hedge)
  end
end
