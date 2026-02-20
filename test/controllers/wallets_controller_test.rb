require "test_helper"

class WalletsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:one))
  end

  test "should get index" do
    get wallets_path
    assert_response :success
  end

  test "should get new" do
    get new_wallet_path
    assert_response :success
  end

  test "should create wallet" do
    network = networks(:ethereum)
    assert_difference "Wallet.count", 1 do
      post wallets_path, params: { wallet: { network_id: network.id, address: "0xnewwallet123" } }
    end
    assert_redirected_to wallets_path
  end

  test "should destroy wallet" do
    wallet = wallets(:one)
    assert_difference "Wallet.count", -1 do
      delete wallet_path(wallet)
    end
    assert_redirected_to wallets_path
  end

  test "should queue sync_now" do
    wallet = wallets(:one)
    post sync_now_wallet_path(wallet)
    assert_redirected_to wallets_path
  end
end
