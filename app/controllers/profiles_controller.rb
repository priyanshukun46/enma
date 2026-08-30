class ProfilesController < ApplicationController
  before_action :require_authentication

  def show
    @user = current_user
  end

  def update
    @user = current_user

    if @user.update(profile_params)
      flash[:notice] = "Profile updated successfully."
      redirect_to profile_path
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:user).permit(:name, :avatar_url)
  end
end
