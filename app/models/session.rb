# Represents an authenticated browser session for a {User}.
#
# Sessions are created on login and destroyed on logout or password reset.
# The session ID is persisted in a signed +:session_id+ cookie.
class Session < ApplicationRecord
  belongs_to :user
end
