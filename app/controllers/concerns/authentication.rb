# Provides session-based authentication for controllers.
#
# Included by {ApplicationController}. Uses signed cookies to persist the
# session ID across requests. Exposes {#authenticated?} as a view helper
# and gates every action behind {#require_authentication} unless the
# controller opts out via {ClassMethods#allow_unauthenticated_access}.
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    # Allows certain actions to bypass the authentication check.
    #
    # @param options [Hash] options forwarded to +skip_before_action+
    #   (e.g. <tt>only:</tt>, <tt>except:</tt>)
    # @return [void]
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private

  # Returns the current session if one is active.
  #
  # @return [Session, nil] the active session, or +nil+ if unauthenticated
  def authenticated?
    resume_session
  end

  # Ensures a session is active, redirecting to the login page if not.
  #
  # @return [Session, nil]
  def require_authentication
    resume_session || request_authentication
  end

  # Restores the current session from the signed cookie, if present.
  #
  # @return [Session, nil]
  def resume_session
    Current.session ||= find_session_by_cookie
  end

  # Looks up a {Session} from the signed +:session_id+ cookie.
  #
  # @return [Session, nil]
  def find_session_by_cookie
    Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
  end

  # Stores the current URL and redirects the user to the login page.
  #
  # @return [void]
  def request_authentication
    session[:return_to_after_authenticating] = request.url
    redirect_to new_session_path
  end

  # Returns the URL the user should be redirected to after logging in.
  #
  # Pops the stored return URL from the session, falling back to root.
  #
  # @return [String] the redirect URL
  def after_authentication_url
    session.delete(:return_to_after_authenticating) || root_url
  end

  # Creates a new {Session} for the given user and sets the session cookie.
  #
  # @param user [User] the user who authenticated
  # @return [Session] the newly created session
  def start_new_session_for(user)
    user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
      Current.session = session
      cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax }
    end
  end

  # Destroys the current session and clears the session cookie.
  #
  # @return [void]
  def terminate_session
    Current.session.destroy
    cookies.delete(:session_id)
  end
end
