require "test_helper"

class NetworkTest < ActiveSupport::TestCase
  test "validates uniqueness of name" do
    network = Network.new(name: "ethereum", chain_id: 999)
    assert_not network.valid?
  end

  test "validates uniqueness of chain_id" do
    network = Network.new(name: "newchain", chain_id: 1)
    assert_not network.valid?
  end
end
