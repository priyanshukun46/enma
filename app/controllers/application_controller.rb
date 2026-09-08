require "pagy"

class ApplicationController < ActionController::Base
  include Authentication
  include Pagy::Backend

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Gracefully recover from expired CSRF authenticity tokens
  rescue_from ActionController::InvalidAuthenticityToken do
    reset_session
    redirect_to login_path, alert: "Your security session expired or was refreshed. Please try signing in."
  end

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes
end
