module Hedging
  class CircuitBreaker
    FAILURE_THRESHOLD = 3
    RESET_TIMEOUT = 30.minutes

    class CircuitOpen < StandardError; end

    def initialize(cache_key: "hedging:circuit_breaker")
      @cache_key = cache_key
    end

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

    def open?
      failures >= FAILURE_THRESHOLD && !timeout_expired?
    end

    def closed?
      !open?
    end

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

    def reset!
      Rails.cache.delete(failure_count_key)
      Rails.cache.delete(last_failure_key)
    end

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
