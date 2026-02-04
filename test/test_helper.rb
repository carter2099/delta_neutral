ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"
require "webmock/minitest"
require "httpx/adapters/webmock"
require "vcr"

VCR.configure do |config|
  config.cassette_library_dir = "test/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.allow_http_connections_when_no_cassette = false
  config.default_cassette_options = { record: :new_episodes }
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    def load_subgraph_fixture(name)
      ::JSON.parse(File.read(Rails.root.join("test/fixtures/files/subgraph_responses/#{name}.json")))
    end
  end
end
