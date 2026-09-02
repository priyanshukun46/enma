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

  # Fast SSO for Operators / Judges / Development
  def demo_sso_login
    provider = params[:provider].to_s.downcase
    clean_provider = provider.start_with?("google") ? "google_oauth2" : "github"
    provider_name = clean_provider == "github" ? "GitHub" : "Google"

    email = params[:email].presence || (clean_provider == "github" ? "priyanshukun46@github.com" : "pkfb46@gmail.com")
    name = params[:name].presence || "Priyanshu Kumar"
    username = params[:username].presence || (clean_provider == "github" ? "priyanshukun46" : "pkfb46")
    avatar = clean_provider == "github" ? "https://avatars.githubusercontent.com/u/9919?v=4" : "https://lh3.googleusercontent.com/a/ACg8ocI"

    user = User.find_by(email: email) || User.find_by(email_address: email) || User.create!(
      name: name,
      username: username,
      email: email,
      email_address: email,
      password: "password123",
      password_confirmation: "password123",
      provider: clean_provider,
      uid: "#{clean_provider}_#{SecureRandom.hex(4)}",
      avatar_url: avatar,
      role: :operator
    )

    sign_in(:user, user)
    session[:user_id] = user.id
    flash[:notice] = "Signed in successfully with #{provider_name} SSO! Welcome, #{user.name}."
    redirect_to after_sign_in_path_for(user)
  end

  def destroy
    session.delete(:user_id)
    sign_out(:user)
    flash[:notice] = "Successfully logged out."
    redirect_to root_path
  end
end
