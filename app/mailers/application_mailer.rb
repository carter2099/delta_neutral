# Base mailer for all application emails.
#
# Reads the default +from+ address from the +SMTP_USERNAME+ environment
# variable, falling back to +noreply@example.com+.
class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("SMTP_USERNAME", "noreply@example.com")
  layout "mailer"
end
