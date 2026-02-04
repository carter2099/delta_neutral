require "test_helper"

class Hedging::CircuitBreakerTest < ActiveSupport::TestCase
  setup do
    @cache_key = "test:circuit:#{SecureRandom.hex(4)}"
    @circuit_breaker = Hedging::CircuitBreaker.new(cache_key: @cache_key)
    @circuit_breaker.reset!
  end

  teardown do
    @circuit_breaker.reset!
  end

  test "starts in closed state" do
    assert @circuit_breaker.closed?
    refute @circuit_breaker.open?
  end

  test "stays closed after successful calls" do
    result = @circuit_breaker.call { "success" }

    assert_equal "success", result
    assert @circuit_breaker.closed?
    assert_equal 0, @circuit_breaker.failures
  end

  test "increments failures on error" do
    assert_raises RuntimeError do
      @circuit_breaker.call { raise "error" }
    end

    assert_equal 1, @circuit_breaker.failures
    assert @circuit_breaker.closed?  # Still closed after 1 failure
  end

  test "opens after 3 consecutive failures" do
    3.times do
      assert_raises RuntimeError do
        @circuit_breaker.call { raise "error" }
      end
    end

    assert @circuit_breaker.open?
    assert_equal 3, @circuit_breaker.failures
  end

  test "raises CircuitOpen when circuit is open" do
    3.times do
      assert_raises(RuntimeError) { @circuit_breaker.call { raise "error" } }
    end

    assert_raises Hedging::CircuitBreaker::CircuitOpen do
      @circuit_breaker.call { "would succeed" }
    end
  end

  test "resets failures after success" do
    2.times do
      assert_raises(RuntimeError) { @circuit_breaker.call { raise "error" } }
    end

    @circuit_breaker.call { "success" }

    assert_equal 0, @circuit_breaker.failures
    assert @circuit_breaker.closed?
  end

  test "reset! clears all state" do
    3.times do
      assert_raises(RuntimeError) { @circuit_breaker.call { raise "error" } }
    end

    assert @circuit_breaker.open?

    @circuit_breaker.reset!

    assert @circuit_breaker.closed?
    assert_equal 0, @circuit_breaker.failures
  end

  test "status returns current state" do
    status = @circuit_breaker.status

    assert_equal :closed, status[:state]
    assert_equal 0, status[:failures]
    assert_nil status[:last_failure]
  end
end
