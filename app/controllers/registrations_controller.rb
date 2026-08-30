class RegistrationsController < ApplicationController
  def new
    redirect_to root_path if authenticated?
    @user = User.new
  end

  def create
    @user = User.new(registration_params)
    @user.role = :operator # Security: Default role is always operator

    if @user.save
      login(@user)
      flash[:notice] = "Account created successfully! Welcome to ENMA AI, #{@user.name}."
      redirect_to root_path
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  private

  def registration_params
    params.require(:user).permit(:name, :email_address, :password, :password_confirmation)
  end
end
