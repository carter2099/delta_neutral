require "test_helper"

class UniswapServiceTest < ActiveSupport::TestCase
  setup do
    @service = UniswapService.new(
      subgraph_url: "https://api.thegraph.com/subgraphs/test",
      api_key: "test-key"
    )
  end

  test "fetch_positions returns parsed position data" do
    response_body = {
      data: {
        positions: [
          {
            "id" => "12345",
            "liquidity" => "1000000",
            "depositedToken0" => "2.0",
            "depositedToken1" => "4000.0",
            "withdrawnToken0" => "0.5",
            "withdrawnToken1" => "1000.0",
            "collectedFeesToken0" => "0.1",
            "collectedFeesToken1" => "200.0",
            "pool" => { "id" => "0xpool123", "token0Price" => "1", "token1Price" => "2000", "liquidity" => "5000000" },
            "token0" => { "id" => "0xweth", "symbol" => "WETH", "decimals" => "18", "derivedETH" => "1.0" },
            "token1" => { "id" => "0xusdc", "symbol" => "USDC", "decimals" => "6", "derivedETH" => "0.0005" }
          }
        ]
      }
    }.to_json

    stub_request(:post, "https://api.thegraph.com/subgraphs/test")
      .to_return(status: 200, body: response_body, headers: { "Content-Type" => "application/json" })

    positions = @service.fetch_positions("0xwallet123")

    assert_equal 1, positions.length
    pos = positions.first
    assert_equal "12345", pos[:external_id]
    assert_equal "WETH", pos[:asset0]
    assert_equal "USDC", pos[:asset1]
    # deposited(2.0) - withdrawn(0.5) + fees(0.1) = 1.6
    assert_equal BigDecimal("1.6"), pos[:asset0_amount]
    # deposited(4000) - withdrawn(1000) + fees(200) = 3200
    assert_equal BigDecimal("3200"), pos[:asset1_amount]
  end

  test "fetch_token_prices_usd computes prices correctly" do
    response_body = {
      data: {
        tokens: [
          { "id" => "0xweth", "symbol" => "WETH", "derivedETH" => "1.0" },
          { "id" => "0xusdc", "symbol" => "USDC", "derivedETH" => "0.0005" }
        ],
        bundle: { "ethPriceUSD" => "2000" }
      }
    }.to_json

    stub_request(:post, "https://api.thegraph.com/subgraphs/test")
      .to_return(status: 200, body: response_body, headers: { "Content-Type" => "application/json" })

    prices = @service.fetch_token_prices_usd(%w[0xweth 0xusdc])

    assert_equal BigDecimal("2000"), prices["WETH"]
    assert_equal BigDecimal("1"), prices["USDC"]
  end

  test "fetch_pool_data returns pool info" do
    response_body = {
      data: {
        pool: {
          "id" => "0xpool123",
          "token0Price" => "1",
          "token1Price" => "2000",
          "liquidity" => "5000000",
          "token0" => { "id" => "0xweth", "symbol" => "WETH", "derivedETH" => "1.0" },
          "token1" => { "id" => "0xusdc", "symbol" => "USDC", "derivedETH" => "0.0005" }
        },
        bundle: { "ethPriceUSD" => "2000" }
      }
    }.to_json

    stub_request(:post, "https://api.thegraph.com/subgraphs/test")
      .to_return(status: 200, body: response_body, headers: { "Content-Type" => "application/json" })

    pool = @service.fetch_pool_data("0xpool123")

    assert_equal "WETH", pool[:token0_symbol]
    assert_equal "USDC", pool[:token1_symbol]
    assert_equal BigDecimal("2000"), pool[:token0_price_usd]
    assert_equal BigDecimal("1"), pool[:token1_price_usd]
  end

  test "raises on HTTP error" do
    stub_request(:post, "https://api.thegraph.com/subgraphs/test")
      .to_return(status: 500, body: "Internal Server Error")

    assert_raises(RuntimeError) { @service.fetch_positions("0xwallet") }
  end

  test "raises on GraphQL errors" do
    response_body = { errors: [ { "message" => "Query failed" } ] }.to_json

    stub_request(:post, "https://api.thegraph.com/subgraphs/test")
      .to_return(status: 200, body: response_body, headers: { "Content-Type" => "application/json" })

    assert_raises(RuntimeError) { @service.fetch_positions("0xwallet") }
  end
end
