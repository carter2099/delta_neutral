require "test_helper"

class WalletTest < ActiveSupport::TestCase
  test "validates address presence" do
    wallet = wallets(:one)
    wallet.address = nil
    assert_not wallet.valid?
  end

  test "belongs to user and network" do
    wallet = wallets(:one)
    assert_equal users(:one), wallet.user
    assert_equal networks(:ethereum), wallet.network
  end
end
