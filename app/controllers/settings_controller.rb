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
end
