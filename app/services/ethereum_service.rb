# Reads on-chain data from Ethereum-compatible networks via JSON-RPC.
#
# Uses plain +Net::HTTP+ to make static calls. Currently supports
# fetching uncollected LP fees from the Uniswap V3 NonfungiblePositionManager.
#
# Requires per-network RPC URL environment variables:
# * +ETHEREUM_RPC_URL+ — Ethereum mainnet
# * +ARBITRUM_RPC_URL+ — Arbitrum
# * +BASE_RPC_URL+ — Base
#
# @example Fetch uncollected fees for a position on Arbitrum
#   service = EthereumService.new(network: "arbitrum")
#   service.fetch_uncollected_fees("12345")
class EthereumService
  # Uniswap V3 NonfungiblePositionManager (same address on mainnet + most L2s)
  POSITION_MANAGER_ADDRESS = "0xC36442b4a4522E871399CD717aBDD847Ab11FE88"

  # collect((uint256,address,uint128,uint128)) function selector
  COLLECT_SELECTOR = "0xfc6f7865"

  MAX_UINT128 = (2**128 - 1)

  # Maps network names to their RPC URL environment variable.
  RPC_ENV_VARS = {
    "ethereum" => "ETHEREUM_RPC_URL",
    "arbitrum" => "ARBITRUM_RPC_URL",
    "base" => "BASE_RPC_URL"
  }.freeze

  # @param network [String] network name (e.g. "ethereum", "arbitrum", "base")
  # @param rpc_url [String, nil] explicit JSON-RPC endpoint; overrides network lookup
  def initialize(network: "ethereum", rpc_url: nil)
    @rpc_url = rpc_url || ENV.fetch(rpc_env_var(network))
  end

  # Fetches uncollected (pending) fees for a Uniswap V3 position via a static
  # call to +NonfungiblePositionManager.collect()+.
  #
  # The call uses +MAX_UINT128+ for both amount parameters, which causes the
  # contract to return the maximum claimable fees without executing a transaction.
  #
  # @param token_id [String, Integer] the Uniswap position NFT token ID
  # @param token0_decimals [Integer] decimal places for token0 (e.g. 18 for WETH, 8 for WBTC)
  # @param token1_decimals [Integer] decimal places for token1
  # @return [Hash] +:uncollected_fees0+ and +:uncollected_fees1+ as BigDecimal (human-readable)
  def fetch_uncollected_fees(token_id, token0_decimals: 18, token1_decimals: 18)
    Rails.logger.debug { "[EthereumService] fetch_uncollected_fees for token #{token_id}" }

    data = encode_collect_call(token_id.to_i)

    result = eth_call(POSITION_MANAGER_ADDRESS, data)

    decode_collect_result(result, token0_decimals: token0_decimals, token1_decimals: token1_decimals)
  rescue => e
    Rails.logger.error("[EthereumService] fetch_uncollected_fees failed for token #{token_id}: #{e.message}")
    { uncollected_fees0: BigDecimal("0"), uncollected_fees1: BigDecimal("0") }
  end

  private

  # Encodes the calldata for collect((uint256,address,uint128,uint128)).
  #
  # The tuple is ABI-encoded as:
  #   - uint256 tokenId
  #   - address recipient (zero address for static call)
  #   - uint128 amount0Max (MAX_UINT128)
  #   - uint128 amount1Max (MAX_UINT128)
  def encode_collect_call(token_id)
    token_id_hex = token_id.to_s(16).rjust(64, "0")
    recipient_hex = "0".rjust(64, "0")
    max128_hex = MAX_UINT128.to_s(16).rjust(64, "0")

    COLLECT_SELECTOR + token_id_hex + recipient_hex + max128_hex + max128_hex
  end

  # Decodes the return data from collect() — two uint256 values (amount0, amount1).
  # Converts from raw integer units to human-readable amounts using token decimals.
  def decode_collect_result(hex_result, token0_decimals: 18, token1_decimals: 18)
    # Strip 0x prefix
    hex = hex_result.sub(/\A0x/, "")

    # Each uint256 is 32 bytes = 64 hex chars
    amount0 = BigDecimal(hex[0, 64].to_i(16))
    amount1 = BigDecimal(hex[64, 64].to_i(16))

    {
      uncollected_fees0: amount0 / BigDecimal(10**token0_decimals),
      uncollected_fees1: amount1 / BigDecimal(10**token1_decimals)
    }
  end

  def rpc_env_var(network)
    RPC_ENV_VARS.fetch(network) do
      raise ArgumentError, "Unknown network: #{network}. Supported: #{RPC_ENV_VARS.keys.join(", ")}"
    end
  end

  # Makes an eth_call JSON-RPC request.
  def eth_call(to, data)
    uri = URI(@rpc_url)
    body = {
      jsonrpc: "2.0",
      method: "eth_call",
      params: [
        { to: to, data: data },
        "latest"
      ],
      id: 1
    }.to_json

    response = Net::HTTP.post(uri, body, "Content-Type" => "application/json")

    unless response.is_a?(Net::HTTPSuccess)
      raise "Ethereum RPC request failed: #{response.code} #{response.body}"
    end

    parsed = JSON.parse(response.body)

    if parsed["error"]
      raise "Ethereum RPC error: #{parsed["error"]["message"]}"
    end

    parsed["result"]
  end
end
