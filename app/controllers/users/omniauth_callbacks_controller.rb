class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  skip_before_action :verify_authenticity_token, only: [:google_oauth2, :github]

  def google_oauth2
    handle_auth("Google")
  end

  def github
    handle_auth("GitHub")
  end

  def failure
    error_type = params[:message].presence || "Authentication failed"
    flash[:alert] = "OAuth sign-in cancelled or failed (#{error_type.to_s.humanize}). Please sign in with email or try again."
    redirect_to login_path
  end

  private

  def handle_auth(kind)
    auth = request.env["omniauth.auth"]

    if auth.blank?
      flash[:alert] = "Authentication was unsuccessful. Missing authentication payload from #{kind}."
      return redirect_to login_path
    end

    if user_signed_in?
      # User is already signed in and connecting their third-party account from Settings
      current_user.update(
        provider: auth.provider,
        uid: auth.uid,
        avatar_url: current_user.avatar_url.presence || auth.dig("info", "image")
      )
      flash[:notice] = "#{kind} account successfully connected to your ENMA AI profile!"
      redirect_to settings_path
    else
      @user = User.from_omniauth(auth)

      if @user&.persisted?
        session[:user_id] = @user.id
        flash[:notice] = "Signed in successfully with #{kind}! Welcome, #{@user.name}."
        sign_in_and_redirect @user, event: :authentication
      else
        session["devise.#{auth.provider}_data"] = auth.except("extra")
        flash[:alert] = "Could not authenticate your #{kind} account. Please register with email."
        redirect_to sign_up_path
      end
    end
  rescue StandardError => e
    Rails.logger.error("OAuth Authentication Error (#{kind}): #{e.message}\n#{e.backtrace.first(5).join("\n")}")
    flash[:alert] = "OAuth authentication encountered an error: #{e.message}"
    redirect_to login_path
  end
end
