class PasswordsController < ApplicationController
  before_action :set_user_by_token, only: [:edit, :update]

  def new
  end

  def create
    user = User.find_by(email_address: params[:email_address].to_s.strip.downcase)

    if user
      token = user.generate_token_for(:password_reset)
      reset_url = edit_password_url(token)
      Rails.logger.info("==========================================")
      Rails.logger.info("ENMA AI PASSWORD RESET URL: #{reset_url}")
      Rails.logger.info("==========================================")
    end

    flash[:notice] = "If an account matches #{params[:email_address]}, password reset instructions have been generated."
    redirect_to login_path
  end

  def edit
  end

  def update
    if params[:password].blank? || params[:password].length < 8
      flash.now[:alert] = "Password must be at least 8 characters long."
      return render :edit, status: :unprocessable_entity
    end

    if params[:password] != params[:password_confirmation]
      flash.now[:alert] = "Password and confirmation do not match."
      return render :edit, status: :unprocessable_entity
    end

    if @user.update(password: params[:password], password_confirmation: params[:password_confirmation])
      login(@user)
      flash[:notice] = "Password reset successfully. Welcome back, #{@user.name}!"
      redirect_to root_path
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user_by_token
    @user = User.find_by_token_for(:password_reset, params[:token])
    unless @user
      flash[:alert] = "Password reset link is invalid or has expired. Please request a new link."
      redirect_to new_password_path
    end
  end
end
