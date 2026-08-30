class OmniauthCallbacksController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:callback]

  def callback
    auth = request.env["omniauth.auth"]

    if auth.blank?
      flash[:alert] = "Authentication was unsuccessful. Missing authentication payload."
      return redirect_to login_path
    end

    user = User.from_omniauth(auth)

    if user.present?
      login(user)
      flash[:notice] = "Signed in successfully with #{user.provider_label}! Welcome, #{user.name}."
      redirect_to(session.delete(:return_to) || root_path)
    else
      flash[:alert] = "Unable to authenticate with #{auth.provider}. Please ensure your account has a verified email address."
      redirect_to login_path
    end
  rescue StandardError => e
    Rails.logger.error("OAuth Authentication Error: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
    flash[:alert] = "OAuth authentication encountered an unexpected error. Please try again."
    redirect_to login_path
  end

  def failure
    error_type = params[:message].presence || "Authentication failed"
    flash[:alert] = "OAuth sign-in cancelled or failed (#{error_type.humanize}). Please sign in with email or try again."
    redirect_to login_path
  end
end
