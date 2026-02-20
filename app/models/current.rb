# Thread-safe store for per-request context.
#
# Uses +ActiveSupport::CurrentAttributes+ to make the current {Session} and
# its associated {User} accessible throughout a request without passing them
# explicitly through method signatures.
#
# @example Access the current user anywhere in a request
#   Current.user  #=> #<User id=1 ...>
class Current < ActiveSupport::CurrentAttributes
  # @!attribute [rw] session
  #   @return [Session, nil] the current authenticated session
  attribute :session
  delegate :user, to: :session, allow_nil: true
end
