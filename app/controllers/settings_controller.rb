class SettingsController < ApplicationController
  before_action :require_authentication

  def show
    @user = current_user
  end

  def update_password
    @user = current_user

    # If user already has a password, verify current password
    if @user.password_digest.present? && !@user.authenticate(params[:current_password])
      flash.now[:alert] = "Current password is incorrect."
      return render :show, status: :unprocessable_entity
    end

    if params[:new_password].blank? || params[:new_password].length < 8
      flash.now[:alert] = "New password must be at least 8 characters long."
      return render :show, status: :unprocessable_entity
    end

    if params[:new_password] != params[:password_confirmation]
      flash.now[:alert] = "New password and confirmation do not match."
      return render :show, status: :unprocessable_entity
    end

    if @user.update(password: params[:new_password], password_confirmation: params[:password_confirmation])
      flash[:notice] = "Security settings updated: password changed successfully."
      redirect_to settings_path
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end
  end

  def connect_sso
    @user = current_user
    provider = params[:provider].to_s.downcase
    
    if %w[google github google_oauth2].include?(provider)
      clean_provider = provider.start_with?("google") ? "google_oauth2" : "github"
      provider_name = clean_provider == "github" ? "GitHub" : "Google"
      simulated_uid = "#{clean_provider}_user_#{SecureRandom.hex(6)}"
      avatar = clean_provider == "github" ? "https://avatars.githubusercontent.com/u/9919?v=4" : "https://lh3.googleusercontent.com/a/ACg8ocI"

      @user.update(
        provider: clean_provider,
        uid: @user.uid.presence || simulated_uid,
        avatar_url: @user.avatar_url.presence || avatar
      )
      flash[:notice] = "#{provider_name} account connected successfully to your profile!"
    else
      flash[:alert] = "Invalid SSO provider requested."
    end
    redirect_to settings_path
  end

  def disconnect_sso
    @user = current_user
    provider_name = @user.provider_label

    if @user.password_digest.blank?
      flash[:alert] = "You must set a password above before disconnecting #{provider_name} to ensure you don't lose account access."
    else
      @user.update(provider: nil, uid: nil)
      flash[:notice] = "#{provider_name} SSO disconnected successfully from your profile."
    end
    redirect_to settings_path
  end
end
