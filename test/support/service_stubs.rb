module ServiceStubs
  def stub_uniswap_positions(wallet_address, positions)
    body = {
      data: {
        positions: positions.map do |pos|
          {
            "id" => pos[:external_id],
            "liquidity" => pos[:liquidity] || "1000000",
            "depositedToken0" => pos[:asset0_amount].to_s,
            "depositedToken1" => pos[:asset1_amount].to_s,
            "withdrawnToken0" => "0",
            "withdrawnToken1" => "0",
            "collectedFeesToken0" => "0",
            "collectedFeesToken1" => "0",
            "pool" => {
              "id" => pos[:pool_address],
              "token0Price" => "1",
              "token1Price" => "2000",
              "liquidity" => "1000000"
            },
            "token0" => {
              "id" => "0xtoken0",
              "symbol" => pos[:asset0],
              "decimals" => "18",
              "derivedETH" => "1"
            },
            "token1" => {
              "id" => "0xtoken1",
              "symbol" => pos[:asset1],
              "decimals" => "6",
              "derivedETH" => "0.0005"
            }
          }
        end
      }
    }.to_json

    stub_request(:post, ENV.fetch("UNISWAP_SUBGRAPH_URL", "https://api.thegraph.com/subgraphs/test"))
      .to_return(status: 200, body: body, headers: { "Content-Type" => "application/json" })
  end

  def stub_uniswap_token_prices(eth_price_usd: "2000", tokens: [])
    body = {
      data: {
        tokens: tokens.map do |t|
          { "id" => t[:id], "symbol" => t[:symbol], "derivedETH" => t[:derived_eth] }
        end,
        bundle: { "ethPriceUSD" => eth_price_usd }
      }
    }.to_json

    stub_request(:post, ENV.fetch("UNISWAP_SUBGRAPH_URL", "https://api.thegraph.com/subgraphs/test"))
      .to_return(status: 200, body: body, headers: { "Content-Type" => "application/json" })
  end

  def stub_hyperliquid_user_state(positions: [], account_value: "10000")
    asset_positions = positions.map do |pos|
      {
        "position" => {
          "coin" => pos[:asset],
          "szi" => pos[:size].to_s,
          "entryPx" => pos[:entry_price].to_s,
          "positionValue" => (pos[:position_value] || "1000").to_s,
          "marginUsed" => (pos[:margin_used] || "100").to_s,
          "unrealizedPnl" => (pos[:unrealized_pnl] || "0").to_s,
          "returnOnEquity" => (pos[:return_on_equity] || "0").to_s,
          "liquidationPx" => pos[:liquidation_price]&.to_s
        }
      }
    end

    {
      "assetPositions" => asset_positions,
      "marginSummary" => { "accountValue" => account_value }
    }
  end
end
