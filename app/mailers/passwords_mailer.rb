# Delivers password reset emails to users.
class PasswordsMailer < ApplicationMailer
  # Sends a password reset email with a signed token link.
  #
  # @param user [User] the user requesting the password reset
  # @return [Mail::Message]
  def reset(user)
    @user = user
    mail subject: "Reset your password", to: user.email_address
  end
end
