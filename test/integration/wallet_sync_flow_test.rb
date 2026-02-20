require "test_helper"

class WalletSyncFlowTest < ActionDispatch::IntegrationTest
  include ServiceStubs

  setup do
    sign_in_as(users(:one))
    ENV["UNISWAP_SUBGRAPH_URL"] ||= "https://api.thegraph.com/subgraphs/test"
    ENV["THEGRAPH_API_KEY"] ||= "test-key"
  end

  test "user creates wallet and syncs positions" do
    # Create wallet
    network = networks(:ethereum)
    assert_difference "Wallet.count", 1 do
      post wallets_path, params: { wallet: { network_id: network.id, address: "0xintegrationtest123" } }
    end
    assert_redirected_to wallets_path

    wallet = Wallet.last

    # Stub subgraph and sync
    stub_uniswap_positions("0xintegrationtest123", [
      {
        external_id: "integ-pos-1",
        pool_address: "0xintpool",
        asset0: "WETH",
        asset1: "USDC",
        asset0_amount: "1.0",
        asset1_amount: "2000.0"
      }
    ])

    assert_difference "Position.count", 1 do
      WalletSyncJob.perform_now(wallet.id)
    end

    # Verify position shows on positions page
    get positions_path
    assert_response :success
  end
end
