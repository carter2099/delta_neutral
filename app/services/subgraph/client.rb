module Subgraph
  # HTTP client for querying The Graph's hosted subgraph endpoints via GraphQL.
  #
  # Sends POST requests with HTTPX and handles API key injection, HTTP errors,
  # and GraphQL-level error responses.
  #
  # @example
  #   client = Subgraph::Client.new(url: "https://gateway.thegraph.com/api/subgraphs/id/abc")
  #   data = client.query("{ positions(first: 10) { id } }")
  class Client
    class Error < StandardError; end
    # Raised when the GraphQL response contains errors in the +errors+ key.
    class QueryError < Error; end
    # Raised on HTTP-level failures (timeouts, connection errors, non-200 status).
    class NetworkError < Error; end

    # @param url [String] the subgraph endpoint URL
    # @param api_key [String, nil] The Graph API key (falls back to +GRAPH_API_KEY+ env var)
    def initialize(url:, api_key: nil)
      @url = url
      @api_key = api_key || ENV["GRAPH_API_KEY"]
    end

    # Execute a GraphQL query against the subgraph.
    #
    # @param graphql_query [String] the GraphQL query string
    # @param variables [Hash] variables to pass to the query (default: +{}+)
    # @return [Hash] the +data+ key from the GraphQL response
    # @raise [QueryError] if the response contains GraphQL errors
    # @raise [NetworkError] if the HTTP request fails or returns a non-200 status
    def query(graphql_query, variables: {})
      full_url = build_url

      response = HTTPX.post(
        full_url,
        json: {
          query: graphql_query,
          variables: variables
        },
        headers: headers
      )

      handle_response(response)
    rescue HTTPX::Error => e
      raise NetworkError, "Network error: #{e.message}"
    end

    private

    def build_url
      if @api_key && @url.include?("gateway.thegraph.com")
        # The Graph's hosted service requires API key in URL path
        @url.sub("gateway.thegraph.com/api/", "gateway.thegraph.com/api/#{@api_key}/")
      else
        @url
      end
    end

    def headers
      {
        "Content-Type" => "application/json",
        "Accept" => "application/json"
      }
    end

    def handle_response(response)
      # Handle HTTPX error responses (timeouts, connection errors)
      if response.is_a?(HTTPX::ErrorResponse)
        raise NetworkError, "Network error: #{response.error.message}"
      end

      unless response.status == 200
        raise NetworkError, "HTTP #{response.status}: #{response.body}"
      end

      data = JSON.parse(response.body.to_s)

      if data["errors"]
        error_messages = data["errors"].map { |e| e["message"] }.join(", ")
        raise QueryError, "GraphQL errors: #{error_messages}"
      end

      data["data"]
    end
  end
end
