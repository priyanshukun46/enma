class Users::SessionsController < Devise::SessionsController
  layout "auth"

  # Render login form
  def new
    if user_signed_in?
      redirect_to dashboard_path and return
    end
    super
  end

  # Sign in via Devise Warden with support for email/username/email_address params
  def create
    login_param = params.dig(:user, :login).presence ||
                  params.dig(:user, :email).presence ||
                  params.dig(:user, :email_address).presence ||
                  params[:login].presence ||
                  params[:email_address].presence ||
                  params[:email].presence ||
                  params[:username].presence

    pass = params.dig(:user, :password).presence || params[:password].presence

    user = User.find_by_login(login_param)

    # Auto-provision default demo accounts on demand if not yet in database
    if user.nil? && %w[admin operator].include?(login_param.to_s.strip.downcase) && pass == "password123"
      user = User.seed_demo_account(login_param.to_s.strip.downcase)
    end

    if user && user.valid_password?(pass)
      sign_in(:user, user)
      session[:user_id] = user.id
      flash[:notice] = "Welcome back, #{user.name}!"
      redirect_to(session.delete(:user_return_to) || session.delete(:return_to) || after_sign_in_path_for(user))
    else
      flash.now[:alert] = "Invalid username, email, or password. Please verify your credentials and try again."
      self.resource = resource_class.new
      clean_up_passwords(resource)
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session.delete(:user_id)
    sign_out(:user)
    flash[:notice] = "Successfully logged out."
    redirect_to root_path
  end
end
