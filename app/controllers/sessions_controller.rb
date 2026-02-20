# Manages user sessions (login and logout).
#
# The +create+ action is rate-limited to 10 attempts per 3 minutes to
# mitigate brute-force attacks.
class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  # GET /session/new
  #
  # Renders the login form.
  def new
  end

  # POST /session
  #
  # Authenticates the user with email and password. On success, starts a new
  # session and redirects to the post-authentication URL. On failure,
  # redirects back to the login form with an alert.
  #
  # @return [void]
  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "Try another email address or password."
    end
  end

  # DELETE /session
  #
  # Terminates the current session and redirects to the login page.
  #
  # @return [void]
  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end
end
