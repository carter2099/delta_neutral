require "test_helper"

class WalletSyncJobTest < ActiveSupport::TestCase
  include ServiceStubs

  setup do
    ENV["UNISWAP_SUBGRAPH_URL"] ||= "https://api.thegraph.com/subgraphs/test"
    ENV["THEGRAPH_API_KEY"] ||= "test-key"
  end

  test "creates new positions from subgraph" do
    wallet = wallets(:one)

    stub_uniswap_positions(wallet.address, [
      {
        external_id: "99999",
        pool_address: "0xnewpool",
        asset0: "WETH",
        asset1: "USDC",
        asset0_amount: "2.0",
        asset1_amount: "4000.0"
      }
    ])

    assert_difference "Position.count", 1 do
      WalletSyncJob.perform_now(wallet.id)
    end

    new_pos = Position.find_by(external_id: "99999")
    assert_equal "WETH", new_pos.asset0
    assert_equal "USDC", new_pos.asset1
    assert new_pos.active?
  end

  test "marks missing positions as inactive" do
    wallet = wallets(:one)
    position = positions(:eth_usdc)
    assert position.active?

    stub_uniswap_positions(wallet.address, [])

    WalletSyncJob.perform_now(wallet.id)

    position.reload
    assert_not position.active?
  end
end
