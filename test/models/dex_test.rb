require "test_helper"

class DexTest < ActiveSupport::TestCase
  test "validates uniqueness of name" do
    dex = Dex.new(name: "uniswap")
    assert_not dex.valid?
  end
end
