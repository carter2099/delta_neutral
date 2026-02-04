module Hedging
  # Cache-backed circuit breaker that halts trading after consecutive failures.
  #
  # Opens (blocks execution) after {FAILURE_THRESHOLD} consecutive failures and
  # automatically resets after {RESET_TIMEOUT}. Uses +Rails.cache+ for state
  # persistence across requests and processes.
  #
  # @example Wrapping a trading operation
  #   breaker = Hedging::CircuitBreaker.new
  #   breaker.call { execute_trade! }
  #
  # @example Checking status
  #   breaker.status #=> { state: :closed, failures: 1, ... }
  #   breaker.open?  #=> false
  class CircuitBreaker
    # @return [Integer] number of consecutive failures before the circuit opens
    FAILURE_THRESHOLD = 3
    # @return [ActiveSupport::Duration] time after which an open circuit resets
    RESET_TIMEOUT = 30.minutes

    # Raised when attempting to execute through an open circuit.
    class CircuitOpen < StandardError; end

    # @param cache_key [String] base key for storing circuit state in Rails.cache
    def initialize(cache_key: "hedging:circuit_breaker")
      @cache_key = cache_key
    end

    # Execute a block with circuit breaker protection.
    #
    # Records success or failure and raises {CircuitOpen} if the circuit is open.
    #
    # @yield the operation to protect
    # @return the block's return value
    # @raise [CircuitOpen] if the circuit is currently open
    def call
      raise CircuitOpen, "Circuit breaker is open due to consecutive failures" if open?

      begin
        result = yield
        record_success
        result
      rescue => e
        record_failure
        raise
      end
    end

    # @return [Boolean] true if the circuit is open (blocking execution)
    def open?
      failures >= FAILURE_THRESHOLD && !timeout_expired?
    end

    # @return [Boolean] true if the circuit is closed (allowing execution)
    def closed?
      !open?
    end

    # @return [Integer] current consecutive failure count
    def failures
      Rails.cache.read(failure_count_key) || 0
    end

    def record_success
      Rails.cache.delete(failure_count_key)
      Rails.cache.delete(last_failure_key)
    end

    def record_failure
      current = failures
      Rails.cache.write(failure_count_key, current + 1, expires_in: 1.hour)
      Rails.cache.write(last_failure_key, Time.current, expires_in: 1.hour)
    end

    # Manually reset the circuit breaker, clearing all failure state.
    # @return [void]
    def reset!
      Rails.cache.delete(failure_count_key)
      Rails.cache.delete(last_failure_key)
    end

    # @return [Hash] current circuit state with keys +:state+ (:open/:closed),
    #   +:failures+, +:last_failure+, +:will_reset_at+
    def status
      {
        state: open? ? :open : :closed,
        failures: failures,
        last_failure: last_failure_time,
        will_reset_at: will_reset_at
      }
    end

    private

    def failure_count_key
      "#{@cache_key}:failures"
    end

    def last_failure_key
      "#{@cache_key}:last_failure"
    end

    def last_failure_time
      Rails.cache.read(last_failure_key)
    end

    def timeout_expired?
      last = last_failure_time
      return true unless last
      Time.current > last + RESET_TIMEOUT
    end

    def will_reset_at
      last = last_failure_time
      return nil unless last && open?
      last + RESET_TIMEOUT
    end
  end
end
