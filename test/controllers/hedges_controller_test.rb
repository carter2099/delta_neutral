require "test_helper"

class HedgesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  test "should get index" do
    get hedges_path
    assert_response :success
  end

  test "should get show" do
    hedge = hedges(:eth_hedge)
    get hedge_path(hedge)
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
    closed_assets = []

    mock_service = Minitest::Mock.new
    mock_service.expect(:close_short, nil, asset: "ETH")
    mock_service.expect(:close_short, nil, asset: "USDC")

    HyperliquidService.stub(:new, mock_service) do
      assert_difference "Hedge.count", -1 do
        delete hedge_path(hedge)
      end
    end

    assert_redirected_to hedges_path
    mock_service.verify
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
