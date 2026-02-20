# Handles password reset requests and token-based password updates.
#
# The +create+ action is rate-limited to 10 requests per 3 minutes to
# prevent abuse. Deliberately avoids leaking whether a user exists for
# the given email address.
class PasswordsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user_by_token, only: %i[ edit update ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_password_path, alert: "Try again later." }

  # GET /passwords/new
  #
  # Renders the "forgot password" form.
  def new
  end

  # POST /passwords
  #
  # Sends a password reset email if a user exists for the given address.
  # Always redirects to the login page to avoid disclosing user existence.
  #
  # @return [void]
  def create
    if user = User.find_by(email_address: params[:email_address])
      PasswordsMailer.reset(user).deliver_later
    end

    redirect_to new_session_path, notice: "Password reset instructions sent (if user with that email address exists)."
  end

  # GET /passwords/:token/edit
  #
  # Renders the password reset form for a valid token.
  def edit
  end

  # PATCH /passwords/:token
  #
  # Updates the user's password if the confirmation matches, then destroys
  # all existing sessions and redirects to the login page.
  #
  # @return [void]
  def update
    if @user.update(params.permit(:password, :password_confirmation))
      @user.sessions.destroy_all
      redirect_to new_session_path, notice: "Password has been reset."
    else
      redirect_to edit_password_path(params[:token]), alert: "Passwords did not match."
    end
  end

  private

  # Finds the user identified by the signed password-reset token.
  #
  # Redirects to the "new password" form if the token is invalid or expired.
  #
  # @return [void]
  def set_user_by_token
    @user = User.find_by_password_reset_token!(params[:token])
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to new_password_path, alert: "Password reset link is invalid or has expired."
  end
end
