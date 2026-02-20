# Queries the Uniswap v3 subgraph for positions, token prices, and pool data.
#
# Reads configuration from environment variables by default:
# * +UNISWAP_SUBGRAPH_URL+ — The Graph endpoint for Uniswap v3
# * +THEGRAPH_API_KEY+ — optional bearer token for authenticated subgraph access
#
# All GraphQL queries are executed via plain +Net::HTTP+ POST requests.
#
# @example Fetch positions for a wallet
#   service = UniswapService.new
#   service.fetch_positions("0xabc...")
class UniswapService
  POSITIONS_QUERY = <<~GRAPHQL
    query($owner: String!) {
      positions(where: { owner: $owner, liquidity_gt: "0" }) {
        id
        depositedToken0
        depositedToken1
        withdrawnToken0
        withdrawnToken1
        collectedFeesToken0
        collectedFeesToken1
        pool {
          id
        }
        token0 {
          id
          symbol
          decimals
        }
        token1 {
          id
          symbol
          decimals
        }
      }
    }
  GRAPHQL

  TOKEN_PRICES_QUERY = <<~GRAPHQL
    query($tokenIds: [String!]!) {
      tokens(where: { id_in: $tokenIds }) {
        id
        symbol
        derivedETH
      }
      bundle(id: "1") {
        ethPriceUSD
      }
    }
  GRAPHQL

  POOL_QUERY = <<~GRAPHQL
    query($poolId: String!) {
      pool(id: $poolId) {
        id
        token0Price
        token1Price
        liquidity
        token0 {
          id
          symbol
          derivedETH
        }
        token1 {
          id
          symbol
          derivedETH
        }
      }
      bundle(id: "1") {
        ethPriceUSD
      }
    }
  GRAPHQL

  # @param subgraph_url [String, nil] The Graph subgraph endpoint; falls back
  #   to +UNISWAP_SUBGRAPH_URL+
  # @param api_key [String, nil] bearer token for authenticated access; falls
  #   back to +THEGRAPH_API_KEY+
  def initialize(subgraph_url: nil, api_key: nil)
    @subgraph_url = subgraph_url || ENV.fetch("UNISWAP_SUBGRAPH_URL")
    @api_key = api_key || ENV["THEGRAPH_API_KEY"]
  end

  # Returns the net token amounts for all active positions owned by a wallet.
  #
  # Net amount for each token is: deposited - withdrawn + collected_fees.
  #
  # @param wallet_address [String] the Ethereum wallet address
  # @return [Array<Hash>] each hash includes +:external_id+, +:pool_address+,
  #   +:asset0+, +:asset1+, +:asset0_amount+, +:asset1_amount+
  def fetch_positions(wallet_address)
    Rails.logger.debug { "[UniswapService] fetch_positions for wallet #{wallet_address}" }
    result = execute_query(POSITIONS_QUERY, { owner: wallet_address.downcase })
    positions = result.dig("data", "positions") || []
    Rails.logger.debug { "[UniswapService] fetch_positions returned #{positions.size} position(s)" }

    positions.map do |pos|
      deposited0 = BigDecimal(pos["depositedToken0"])
      withdrawn0 = BigDecimal(pos["withdrawnToken0"])
      fees0 = BigDecimal(pos["collectedFeesToken0"])
      deposited1 = BigDecimal(pos["depositedToken1"])
      withdrawn1 = BigDecimal(pos["withdrawnToken1"])
      fees1 = BigDecimal(pos["collectedFeesToken1"])

      {
        external_id: pos["id"],
        pool_address: pos.dig("pool", "id"),
        asset0: pos.dig("token0", "symbol"),
        asset1: pos.dig("token1", "symbol"),
        asset0_amount: deposited0 - withdrawn0 + fees0,
        asset1_amount: deposited1 - withdrawn1 + fees1
      }
    end
  end

  # Returns USD prices for a set of token contract addresses.
  #
  # Prices are derived by multiplying each token's +derivedETH+ ratio by the
  # current ETH/USD price from the Uniswap +bundle+. Results are keyed by
  # both token contract address and token symbol for convenient lookup.
  #
  # @param token_ids [Array<String>] ERC-20 contract addresses
  # @return [Hash{String => BigDecimal}] map of token address/symbol to USD price
  def fetch_token_prices_usd(token_ids)
    Rails.logger.debug { "[UniswapService] fetch_token_prices_usd for #{token_ids.size} token(s)" }
    result = execute_query(TOKEN_PRICES_QUERY, { tokenIds: token_ids.map(&:downcase) })
    eth_price_usd = BigDecimal(result.dig("data", "bundle", "ethPriceUSD"))
    tokens = result.dig("data", "tokens") || []

    tokens.each_with_object({}) do |token, prices|
      derived_eth = BigDecimal(token["derivedETH"])
      prices[token["id"]] = derived_eth * eth_price_usd
      prices[token["symbol"]] = derived_eth * eth_price_usd
    end
  end

  # Returns current price and liquidity data for a Uniswap v3 pool.
  #
  # Returns +nil+ if the pool is not found in the subgraph.
  #
  # @param pool_address [String] the pool contract address
  # @return [Hash, nil] includes +:token0_price+, +:token1_price+,
  #   +:liquidity+, +:token0_symbol+, +:token1_symbol+,
  #   +:token0_price_usd+, +:token1_price_usd+; +nil+ if pool not found
  def fetch_pool_data(pool_address)
    Rails.logger.debug { "[UniswapService] fetch_pool_data for pool #{pool_address}" }
    result = execute_query(POOL_QUERY, { poolId: pool_address.downcase })
    pool = result.dig("data", "pool")
    unless pool
      Rails.logger.debug { "[UniswapService] fetch_pool_data: pool #{pool_address} not found in subgraph" }
      return nil
    end

    eth_price_usd = BigDecimal(result.dig("data", "bundle", "ethPriceUSD"))

    {
      token0_price: BigDecimal(pool["token0Price"]),
      token1_price: BigDecimal(pool["token1Price"]),
      liquidity: pool["liquidity"],
      token0_symbol: pool.dig("token0", "symbol"),
      token1_symbol: pool.dig("token1", "symbol"),
      token0_price_usd: BigDecimal(pool.dig("token0", "derivedETH")) * eth_price_usd,
      token1_price_usd: BigDecimal(pool.dig("token1", "derivedETH")) * eth_price_usd
    }
  end

  private

  # Executes a GraphQL query against the configured subgraph endpoint.
  #
  # @param query [String] the GraphQL query string
  # @param variables [Hash] query variables
  # @return [Hash] parsed JSON response body
  # @raise [RuntimeError] if the HTTP response indicates failure or the
  #   GraphQL response contains errors
  def execute_query(query, variables = {})
    uri = URI(@subgraph_url)
    query_name = query[/query\s*\(/, 0] ? query[/query.*?\{/m]&.strip&.truncate(60) : "unknown"
    Rails.logger.debug { "[UniswapService] GraphQL request to #{uri.host}: #{query_name}, variables=#{variables.inspect}" }
    headers = { "Content-Type" => "application/json" }
    headers["Authorization"] = "Bearer #{@api_key}" if @api_key.present?

    body = { query: query, variables: variables }.to_json

    response = Net::HTTP.post(uri, body, headers)

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.debug { "[UniswapService] HTTP error: #{response.code}" }
      raise "Uniswap subgraph request failed: #{response.code} #{response.body}"
    end

    parsed = JSON.parse(response.body)

    if parsed["errors"]&.any?
      Rails.logger.debug { "[UniswapService] GraphQL errors: #{parsed["errors"].map { |e| e["message"] }.join(", ")}" }
      raise "Uniswap subgraph query error: #{parsed["errors"].map { |e| e["message"] }.join(", ")}"
    end

    Rails.logger.debug { "[UniswapService] GraphQL response OK, data keys: #{parsed["data"]&.keys&.join(", ")}" }
    parsed
  end
end
