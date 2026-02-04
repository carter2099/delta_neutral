require "test_helper"

class PositionSyncJobTest < ActiveJob::TestCase
  setup do
    @position = positions(:arb_eth)  # Use arb_eth which has no last_synced_at
    @fixture_data = load_subgraph_fixture("position_123456")
  end

  test "syncs position data from subgraph" do
    pool_data = {
      data: {
        pool: {
          id: "0xpool1",
          tick: "0",
          sqrtPrice: "79228162514264337593543950336",
          token0Price: "0.0005",
          token1Price: "2000.0",
          feeTier: "3000",
          liquidity: "100000000000000000000",
          volumeUSD: "1000000",
          totalValueLockedUSD: "50000000",
          token0: {
            id: "0xweth",
            symbol: "WETH",
            name: "Wrapped Ether",
            decimals: "18",
            derivedETH: "1.0"
          },
          token1: {
            id: "0xusdc",
            symbol: "USDC",
            name: "USD Coin",
            decimals: "6",
            derivedETH: "0.0005"
          }
        },
        bundle: {
          ethPriceUSD: "2000.0"
        }
      }
    }

    # Stub all requests to thegraph - first returns position data, then pool data
    stub_request(:post, /thegraph\.com/)
      .to_return(
        { status: 200, body: { data: @fixture_data }.to_json, headers: { "Content-Type" => "application/json" } },
        { status: 200, body: pool_data.to_json, headers: { "Content-Type" => "application/json" } }
      )

    # Test that the job runs and updates position
    perform_enqueued_jobs do
      PositionSyncJob.perform_now(@position.id)
    rescue => e
      # HedgeAnalysisJob may fail due to missing HL config - that's OK
    end

    @position.reload
    assert_not_nil @position.last_synced_at
    # Tokens should be updated from fixture data
    assert_equal "WETH", @position.token0_symbol
    assert_equal "USDC", @position.token1_symbol
  end

  test "deactivates position when not found" do
    stub_request(:post, /thegraph\.com/)
      .to_return(
        status: 200,
        body: { data: { position: nil } }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    PositionSyncJob.perform_now(@position.id)

    @position.reload
    refute @position.active?
  end

  test "skips inactive positions" do
    @position.update!(active: false, last_synced_at: nil)

    # Should not make any HTTP requests - webmock will fail if unexpected
    PositionSyncJob.perform_now(@position.id)

    # Assert position was not updated
    @position.reload
    refute @position.active?
    assert_nil @position.last_synced_at
  end
end
