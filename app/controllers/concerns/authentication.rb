module Authentication
  extend ActiveSupport::Concern

  included do
    helper_method :authenticated?, :logged_in?, :current_user
  end

  # Helper method check whether user is signed in
  def authenticated?
    user_signed_in?
  end
  alias_method :logged_in?, :authenticated?

  # Sign in user via Devise warden
  def login(user)
    sign_in(:user, user)
    session[:user_id] = user.id
  end

  # Sign out user via Devise warden
  def logout
    session.delete(:user_id)
    sign_out(:user)
  end

  # Filter to protect authenticated pages
  def require_authentication
    unless user_signed_in?
      session[:user_return_to] = request.fullpath if request.get?
      redirect_to new_user_session_path, alert: "Please sign in to access ResQWay intelligence platform."
    end
  end

  # Filter to restrict admin-only pages
  def require_admin
    unless user_signed_in? && current_user.admin?
      redirect_to dashboard_path, alert: "Access denied. Administrator privileges required."
    end
  end

  # Devise redirect after sign in
  def after_sign_in_path_for(resource)
    stored_location_for(resource) || dashboard_path
  end

  # Devise redirect after sign out
  def after_sign_out_path_for(resource_or_scope)
    root_path
  end
end
