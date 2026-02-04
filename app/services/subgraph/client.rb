module Subgraph
  class Client
    class Error < StandardError; end
    class QueryError < Error; end
    class NetworkError < Error; end

    def initialize(url:, api_key: nil)
      @url = url
      @api_key = api_key || ENV["GRAPH_API_KEY"]
    end

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
