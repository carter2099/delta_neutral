require "test_helper"

class Hedging::SafetyValidatorTest < ActiveSupport::TestCase
  setup do
    @validator = Hedging::SafetyValidator.new
  end

  test "validates valid adjustment" do
    adjustment = {
      asset: "ETH",
      current_size: -8.0,
      target_size: -10.0,
      delta: -2.0
    }
    prices = { "ETH" => 2000.0 }

    assert @validator.validate_single_adjustment!(adjustment, prices: prices)
  end

  test "raises error for missing asset" do
    adjustment = {
      asset: nil,
      current_size: 0,
      target_size: -10.0,
      delta: -10.0
    }

    error = assert_raises Hedging::SafetyValidator::ValidationError do
      @validator.validate_single_adjustment!(adjustment, prices: {})
    end

    assert_equal :missing_asset, error.code
  end

  test "raises error for trade exceeding max size" do
    adjustment = {
      asset: "ETH",
      current_size: 0,
      target_size: -100.0,
      delta: -100.0
    }
    prices = { "ETH" => 2000.0 }  # $200k trade

    error = assert_raises Hedging::SafetyValidator::ValidationError do
      @validator.validate_single_adjustment!(adjustment, prices: prices)
    end

    assert_equal :trade_too_large, error.code
  end

  test "raises error for excessive drift" do
    adjustment = {
      asset: "ETH",
      current_size: -1.0,
      target_size: -1.0,
      delta: -10.0  # 1000% drift (delta/max(current,target) = 10/1 = 10 > 5)
    }

    error = assert_raises Hedging::SafetyValidator::ValidationError do
      @validator.validate_drift!(adjustment)
    end

    assert_equal :excessive_drift, error.code
  end

  test "allows reasonable drift" do
    adjustment = {
      asset: "ETH",
      current_size: -8.0,
      target_size: -10.0,
      delta: -2.0  # 25% drift
    }

    assert @validator.validate_drift!(adjustment)
  end

  test "validates total value across adjustments" do
    adjustments = [
      { asset: "ETH", delta: -25.0 },
      { asset: "BTC", delta: -1.0 }
    ]
    prices = { "ETH" => 2000.0, "BTC" => 50000.0 }  # $50k + $50k = $100k

    assert @validator.validate_total_value!(adjustments, prices: prices)
  end

  test "raises error for total value too large" do
    adjustments = [
      { asset: "ETH", delta: -100.0 },
      { asset: "BTC", delta: -5.0 }
    ]
    prices = { "ETH" => 2000.0, "BTC" => 50000.0 }  # $200k + $250k = $450k

    error = assert_raises Hedging::SafetyValidator::ValidationError do
      @validator.validate_total_value!(adjustments, prices: prices)
    end

    assert_equal :total_too_large, error.code
  end

  test "should_skip_hedge returns true for small values" do
    assert @validator.should_skip_hedge?(5.0)
    refute @validator.should_skip_hedge?(15.0)
  end

  test "warnings_for returns warnings for large trades" do
    adjustments = [
      { asset: "ETH", current_size: 0, target_size: -30.0, delta: -30.0 }
    ]
    prices = { "ETH" => 2000.0 }  # $60k trade

    warnings = @validator.warnings_for(adjustments, prices: prices)

    assert warnings.any? { |w| w.include?("Large trade") }
    assert warnings.any? { |w| w.include?("New position") }
  end
end
