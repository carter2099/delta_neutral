# Base controller for the application.
#
# Includes {Authentication} to enforce login on every action. Restricts
# access to modern browsers and handles missing records gracefully.
class ApplicationController < ActionController::Base
  include Authentication
  allow_browser versions: :modern
  stale_when_importmap_changes

  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  private

  # Redirects to root with an alert when a record is not found.
  #
  # @return [void]
  def record_not_found
    redirect_to root_path, alert: "Record not found."
  end
end
