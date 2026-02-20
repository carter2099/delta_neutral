require "test_helper"

class PositionSyncJobTest < ActiveSupport::TestCase
  setup do
    ENV["UNISWAP_SUBGRAPH_URL"] ||= "https://api.thegraph.com/subgraphs/test"
    ENV["THEGRAPH_API_KEY"] ||= "test-key"
    ENV["HYPERLIQUID_PRIVATE_KEY"] ||= "0xtest"
    ENV["HYPERLIQUID_WALLET_ADDRESS"] ||= "0xwallet"
    ENV["HYPERLIQUID_TESTNET"] ||= "true"
  end

  test "creates pnl snapshot for position" do
    position = positions(:eth_usdc)
    # Remove hedge so we don't need HL calls for hedge PnL
    position.hedge&.destroy

    pool_response = {
      data: {
        pool: {
          "id" => position.pool_address,
          "token0Price" => "1",
          "token1Price" => "2100",
          "liquidity" => "5000000",
          "token0" => { "id" => "0xweth", "symbol" => "WETH", "derivedETH" => "1.0" },
          "token1" => { "id" => "0xusdc", "symbol" => "USDC", "derivedETH" => "0.000476" }
        },
        bundle: { "ethPriceUSD" => "2100" }
      }
    }.to_json

    stub_request(:post, ENV["UNISWAP_SUBGRAPH_URL"])
      .to_return(status: 200, body: pool_response, headers: { "Content-Type" => "application/json" })

    # Stub Hyperliquid API calls
    stub_request(:post, /api\.hyperliquid/)
      .to_return(status: 200, body: { "assetPositions" => [], "marginSummary" => { "accountValue" => "0" } }.to_json,
                 headers: { "Content-Type" => "application/json" })

    assert_difference "PnlSnapshot.count", 1 do
      PositionSyncJob.perform_now(position.id)
    end
  end
end
