class SessionsController < ApplicationController
  def new
    redirect_to root_path if authenticated?
  end

  def create
    user = User.find_by(email_address: params[:email_address].to_s.strip.downcase)

    if user&.authenticate(params[:password])
      login(user)
      flash[:notice] = "Welcome back, #{user.name}!"
      redirect_to(session.delete(:return_to) || root_path)
    else
      flash.now[:alert] = "Invalid email or password. Please verify your credentials and try again."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    logout
    flash[:notice] = "Successfully logged out."
    redirect_to root_path
  end
end
