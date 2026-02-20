# Base class for all background jobs in the application.
#
# Configures shared retry and discard behaviour:
#
# * Deadlocked DB transactions are retried automatically.
# * Jobs referencing deleted records are discarded rather than retried.
# * Transient network timeouts are retried up to 3 times with polynomial back-off.
# * Hyperliquid SDK errors are retried with appropriate back-off; rate limit
#   errors allow 5 attempts with a fixed 30-second delay.
class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  discard_on ActiveJob::DeserializationError

  # Retry on transient network errors
  retry_on Net::OpenTimeout, Net::ReadTimeout, wait: :polynomially_longer, attempts: 3

  # Retry on Hyperliquid SDK transient errors
  retry_on Hyperliquid::NetworkError, wait: :polynomially_longer, attempts: 3
  retry_on Hyperliquid::TimeoutError, wait: :polynomially_longer, attempts: 3
  retry_on Hyperliquid::ServerError, wait: :polynomially_longer, attempts: 3
  retry_on Hyperliquid::RateLimitError, wait: 30.seconds, attempts: 5
end
