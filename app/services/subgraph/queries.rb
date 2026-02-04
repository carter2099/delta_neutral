module Subgraph
  # GraphQL query constants for the Uniswap V3 subgraph.
  #
  # Contains pre-defined queries for fetching position data, owner positions,
  # and pool data including token metadata and pricing information.
  #
  # @see Subgraph::PositionFetcher which uses these queries
  module Queries
    # Fetches a single Uniswap V3 position by its NFT token ID.
    # Includes liquidity, tick range, deposited/withdrawn/collected amounts,
    # pool state, and token metadata.
    # @return [String] GraphQL query accepting +$id: ID!+
    POSITION_BY_ID = <<~GRAPHQL
      query getPosition($id: ID!) {
        position(id: $id) {
          id
          owner
          liquidity
          depositedToken0
          depositedToken1
          withdrawnToken0
          withdrawnToken1
          collectedFeesToken0
          collectedFeesToken1
          tickLower {
            tickIdx
          }
          tickUpper {
            tickIdx
          }
          pool {
            id
            tick
            sqrtPrice
            token0Price
            token1Price
            feeTier
            liquidity
          }
          token0 {
            id
            symbol
            name
            decimals
          }
          token1 {
            id
            symbol
            name
            decimals
          }
        }
      }
    GRAPHQL

    # Fetches all active positions (liquidity > 0) for a given owner address.
    # Results are ordered by ID descending, limited to 100 by default.
    # @return [String] GraphQL query accepting +$owner: String!+ and +$first: Int+
    POSITIONS_BY_OWNER = <<~GRAPHQL
      query getPositionsByOwner($owner: String!, $first: Int = 100) {
        positions(
          where: { owner: $owner, liquidity_gt: "0" }
          first: $first
          orderBy: id
          orderDirection: desc
        ) {
          id
          owner
          liquidity
          depositedToken0
          depositedToken1
          tickLower {
            tickIdx
          }
          tickUpper {
            tickIdx
          }
          pool {
            id
            tick
            sqrtPrice
            token0Price
            token1Price
            feeTier
          }
          token0 {
            id
            symbol
            name
            decimals
          }
          token1 {
            id
            symbol
            name
            decimals
          }
        }
      }
    GRAPHQL

    # Fetches pool-level data including current tick, sqrt price, TVL, volume,
    # fee tier, token metadata with +derivedETH+ pricing, and the ETH/USD
    # bundle price for USD conversion.
    # @return [String] GraphQL query accepting +$id: ID!+
    POOL_DATA = <<~GRAPHQL
      query getPool($id: ID!) {
        pool(id: $id) {
          id
          tick
          sqrtPrice
          token0Price
          token1Price
          feeTier
          liquidity
          volumeUSD
          totalValueLockedUSD
          token0 {
            id
            symbol
            name
            decimals
            derivedETH
          }
          token1 {
            id
            symbol
            name
            decimals
            derivedETH
          }
        }
        bundle(id: "1") {
          ethPriceUSD
        }
      }
    GRAPHQL
  end
end
