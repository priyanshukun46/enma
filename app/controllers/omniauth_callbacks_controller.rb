class OmniauthCallbacksController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:callback]

  def callback
    auth = request.env["omniauth.auth"]

    if auth.blank?
      flash[:alert] = "Authentication was unsuccessful. Missing authentication payload."
      return redirect_to login_path
    end

    if current_user.present?
      # User is already signed in and connecting their third-party account from Settings!
      current_user.update(
        provider: auth.provider,
        uid: auth.uid,
        avatar_url: current_user.avatar_url.presence || auth.dig("info", "image")
      )
      flash[:notice] = "#{auth.provider.titleize} account successfully connected to your ENMA AI profile!"
      redirect_to settings_path
    else
      # Standard OAuth login or registration
      user = User.from_omniauth(auth)

      if user.present?
        login(user)
        flash[:notice] = "Signed in successfully with #{user.provider_label}! Welcome, #{user.name}."
        redirect_to(session.delete(:return_to) || dashboard_path)
      else
        flash[:alert] = "Unable to authenticate with #{auth.provider}. Please ensure your account has a verified email address."
        redirect_to login_path
      end
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
