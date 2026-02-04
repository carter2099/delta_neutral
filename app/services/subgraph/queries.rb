module Subgraph
  module Queries
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
