if Rails.env.production?
  required_vars = %w[
    HYPERLIQUID_PRIVATE_KEY
    HYPERLIQUID_WALLET_ADDRESS
    UNISWAP_SUBGRAPH_URL
    THEGRAPH_API_KEY
  ]

  missing = required_vars.select { |var| ENV[var].blank? }

  if missing.any?
    raise "Missing required environment variables: #{missing.join(', ')}"
  end
end
