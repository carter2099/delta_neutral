require "test_helper"

class Subgraph::PositionFetcherTest < ActiveSupport::TestCase
  setup do
    WebMock.reset!
    @fetcher = Subgraph::PositionFetcher.new(network: "ethereum")
    @fixture_data = load_subgraph_fixture("position_123456")
  end

  teardown do
    WebMock.reset!
  end

  test "fetch normalizes position data" do
    stub_request(:post, /thegraph\.com/)
      .to_return(
        status: 200,
        body: { data: @fixture_data }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    position = @fetcher.fetch("123456")

    assert_equal "123456", position[:id]
    assert_equal "WETH", position[:token0][:symbol]
    assert_equal "USDC", position[:token1][:symbol]
    assert_equal(-100000, position[:tick_lower])
    assert_equal 100000, position[:tick_upper]
    assert_equal 0, position[:pool][:tick]
  end

  test "fetch raises PositionNotFound when position is nil" do
    stub_request(:post, /thegraph\.com/)
      .to_return(
        status: 200,
        body: { data: { position: nil } }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    assert_raises Subgraph::PositionFetcher::PositionNotFound do
      @fetcher.fetch("nonexistent")
    end
  end

  test "fetch_by_owner returns array of positions" do
    stub_request(:post, /thegraph\.com/)
      .to_return(
        status: 200,
        body: { data: { positions: [@fixture_data["position"]] } }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    positions = @fetcher.fetch_by_owner("0x1234567890123456789012345678901234567890")

    assert_kind_of Array, positions
    assert_equal 1, positions.size
    assert_equal "123456", positions.first[:id]
  end

  test "handles network errors" do
    stub_request(:post, /thegraph\.com/)
      .to_timeout

    assert_raises Subgraph::Client::NetworkError do
      @fetcher.fetch("123456")
    end
  end

  test "handles graphql errors" do
    stub_request(:post, /thegraph\.com/)
      .to_return(
        status: 200,
        body: { errors: [{ message: "Invalid query" }] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    assert_raises Subgraph::Client::QueryError do
      @fetcher.fetch("123456")
    end
  end
end
