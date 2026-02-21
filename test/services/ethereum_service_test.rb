require "test_helper"

class EthereumServiceTest < ActiveSupport::TestCase
  setup do
    @service = EthereumService.new(rpc_url: "https://eth.example.com/rpc")
  end

  test "fetch_uncollected_fees returns human-readable amounts with 18 decimals" do
    # amount0 = 1000000000000000000 (1e18 wei = 1.0 token)
    # amount1 = 2000000000000000000 (2e18 wei = 2.0 tokens)
    amount0_hex = "0000000000000000000000000000000000000000000000000de0b6b3a7640000"
    amount1_hex = "0000000000000000000000000000000000000000000000001bc16d674ec80000"
    result_hex = "0x" + amount0_hex + amount1_hex

    rpc_response = { jsonrpc: "2.0", id: 1, result: result_hex }.to_json

    stub_request(:post, "https://eth.example.com/rpc")
      .to_return(status: 200, body: rpc_response, headers: { "Content-Type" => "application/json" })

    fees = @service.fetch_uncollected_fees("12345", token0_decimals: 18, token1_decimals: 18)

    assert_equal BigDecimal("1"), fees[:uncollected_fees0]
    assert_equal BigDecimal("2"), fees[:uncollected_fees1]
  end

  test "fetch_uncollected_fees normalizes with different decimals per token" do
    # amount0 = 100000000 (1e8 = 1.0 WBTC with 8 decimals)
    # amount1 = 1000000000000000000 (1e18 = 1.0 WETH with 18 decimals)
    amount0_hex = "0000000000000000000000000000000000000000000000000000000005f5e100"
    amount1_hex = "0000000000000000000000000000000000000000000000000de0b6b3a7640000"
    result_hex = "0x" + amount0_hex + amount1_hex

    rpc_response = { jsonrpc: "2.0", id: 1, result: result_hex }.to_json

    stub_request(:post, "https://eth.example.com/rpc")
      .to_return(status: 200, body: rpc_response, headers: { "Content-Type" => "application/json" })

    fees = @service.fetch_uncollected_fees("12345", token0_decimals: 8, token1_decimals: 18)

    assert_equal BigDecimal("1"), fees[:uncollected_fees0]
    assert_equal BigDecimal("1"), fees[:uncollected_fees1]
  end

  test "fetch_uncollected_fees returns zeros on RPC error" do
    rpc_response = { jsonrpc: "2.0", id: 1, error: { code: -32000, message: "execution reverted" } }.to_json

    stub_request(:post, "https://eth.example.com/rpc")
      .to_return(status: 200, body: rpc_response, headers: { "Content-Type" => "application/json" })

    fees = @service.fetch_uncollected_fees("99999")

    assert_equal BigDecimal("0"), fees[:uncollected_fees0]
    assert_equal BigDecimal("0"), fees[:uncollected_fees1]
  end

  test "fetch_uncollected_fees returns zeros on HTTP error" do
    stub_request(:post, "https://eth.example.com/rpc")
      .to_return(status: 500, body: "Internal Server Error")

    fees = @service.fetch_uncollected_fees("12345")

    assert_equal BigDecimal("0"), fees[:uncollected_fees0]
    assert_equal BigDecimal("0"), fees[:uncollected_fees1]
  end

  test "encodes collect call with correct selector and parameters" do
    data = @service.send(:encode_collect_call, 12345)

    # Function selector for collect((uint256,address,uint128,uint128))
    assert data.start_with?("0xfc6f7865")
    # Token ID 12345 = 0x3039
    assert_includes data, "3039".rjust(64, "0")
  end
end
