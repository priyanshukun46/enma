module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :set_current_user
    helper_method :current_user, :authenticated?, :logged_in?
  end

  private

  def set_current_user
    Current.user = find_current_user
  end

  def find_current_user
    return nil unless session[:user_id].present?
    User.find_by(id: session[:user_id])
  end

  def current_user
    Current.user ||= find_current_user
  end

  def authenticated?
    current_user.present?
  end
  alias_method :logged_in?, :authenticated?

  def login(user)
    reset_session
    session[:user_id] = user.id
    Current.user = user
  end

  def logout
    reset_session
    Current.user = nil
  end

  def require_authentication
    unless authenticated?
      session[:return_to] = request.fullpath if request.get?
      redirect_to login_path, alert: "Please sign in to access ENMA AI intelligence platform."
    end
  end

  def require_admin
    unless authenticated? && current_user.admin?
      redirect_to root_path, alert: "Access denied. Administrator privileges required."
    end
  end
end
