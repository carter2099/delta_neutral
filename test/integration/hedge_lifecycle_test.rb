require "test_helper"

class HedgeLifecycleTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  test "full hedge lifecycle: create, view, update, delete" do
    position = positions(:eth_usdc)

    # Remove existing hedge to test creation
    position.hedge&.destroy

    mock_service = Object.new
    mock_service.define_singleton_method(:get_position) { |_| nil }
    mock_service.define_singleton_method(:close_short) { |**_| nil }

    HyperliquidService.stub(:new, mock_service) do
      # Create hedge
      assert_difference "Hedge.count", 1 do
        post hedges_path, params: { hedge: { position_id: position.id, target: 0.5, tolerance: 0.05 } }
      end
      hedge = Hedge.last
      assert_redirected_to hedge_path(hedge)

      # View hedge
      get hedge_path(hedge)
      assert_response :success

      # Edit hedge
      get edit_hedge_path(hedge)
      assert_response :success

      # Update hedge
      patch hedge_path(hedge), params: { hedge: { target: 0.7, tolerance: 0.03 } }
      assert_redirected_to hedge_path(hedge)
      hedge.reload
      assert_equal BigDecimal("0.7"), hedge.target

      # Delete hedge
      assert_difference "Hedge.count", -1 do
        delete hedge_path(hedge)
      end
      assert_redirected_to hedges_path
    end
  end
end
