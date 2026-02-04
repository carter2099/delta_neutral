module Subgraph
  class PositionFetcher
    class PositionNotFound < StandardError; end

    def initialize(network: "ethereum")
      @network = network
      @client = Client.new(url: subgraph_url)
    end

    def fetch(nft_id)
      result = @client.query(Queries::POSITION_BY_ID, variables: { id: nft_id.to_s })

      position_data = result["position"]
      raise PositionNotFound, "Position #{nft_id} not found on #{@network}" unless position_data

      normalize_position(position_data)
    end

    def fetch_by_owner(owner_address)
      result = @client.query(
        Queries::POSITIONS_BY_OWNER,
        variables: { owner: owner_address.downcase }
      )

      (result["positions"] || []).map { |p| normalize_position(p) }
    end

    def fetch_pool(pool_address)
      result = @client.query(Queries::POOL_DATA, variables: { id: pool_address.downcase })

      pool_data = result["pool"]
      return nil unless pool_data

      eth_price_usd = result.dig("bundle", "ethPriceUSD")&.to_f || 0

      {
        id: pool_data["id"],
        tick: pool_data["tick"].to_i,
        sqrt_price: pool_data["sqrtPrice"],
        token0_price: pool_data["token0Price"].to_f,
        token1_price: pool_data["token1Price"].to_f,
        fee_tier: pool_data["feeTier"].to_i,
        liquidity: pool_data["liquidity"],
        volume_usd: pool_data["volumeUSD"].to_f,
        tvl_usd: pool_data["totalValueLockedUSD"].to_f,
        token0: normalize_token(pool_data["token0"], eth_price_usd),
        token1: normalize_token(pool_data["token1"], eth_price_usd),
        eth_price_usd: eth_price_usd
      }
    end

    private

    def subgraph_url
      Position::NETWORKS.dig(@network, :subgraph_url)
    end

    def normalize_position(data)
      {
        id: data["id"],
        owner: data["owner"],
        liquidity: data["liquidity"],
        tick_lower: data.dig("tickLower", "tickIdx").to_i,
        tick_upper: data.dig("tickUpper", "tickIdx").to_i,
        deposited_token0: data["depositedToken0"].to_f,
        deposited_token1: data["depositedToken1"].to_f,
        withdrawn_token0: data["withdrawnToken0"]&.to_f || 0,
        withdrawn_token1: data["withdrawnToken1"]&.to_f || 0,
        collected_fees_token0: data["collectedFeesToken0"]&.to_f || 0,
        collected_fees_token1: data["collectedFeesToken1"]&.to_f || 0,
        pool: {
          id: data.dig("pool", "id"),
          tick: data.dig("pool", "tick").to_i,
          sqrt_price: data.dig("pool", "sqrtPrice"),
          token0_price: data.dig("pool", "token0Price").to_f,
          token1_price: data.dig("pool", "token1Price").to_f,
          fee_tier: data.dig("pool", "feeTier").to_i,
          liquidity: data.dig("pool", "liquidity")
        },
        token0: {
          address: data.dig("token0", "id"),
          symbol: data.dig("token0", "symbol"),
          name: data.dig("token0", "name"),
          decimals: data.dig("token0", "decimals").to_i
        },
        token1: {
          address: data.dig("token1", "id"),
          symbol: data.dig("token1", "symbol"),
          name: data.dig("token1", "name"),
          decimals: data.dig("token1", "decimals").to_i
        }
      }
    end

    def normalize_token(token_data, eth_price_usd)
      derived_eth = token_data["derivedETH"]&.to_f || 0
      {
        address: token_data["id"],
        symbol: token_data["symbol"],
        name: token_data["name"],
        decimals: token_data["decimals"].to_i,
        derived_eth: derived_eth,
        price_usd: derived_eth * eth_price_usd
      }
    end
  end
end
