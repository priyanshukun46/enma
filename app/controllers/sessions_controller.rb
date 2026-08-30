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

  def demo_sso_login
    provider = params[:provider].to_s.downcase
    clean_provider = provider.start_with?("google") ? "google_oauth2" : "github"
    provider_name = clean_provider == "github" ? "GitHub" : "Google"
    
    email = "demo.#{clean_provider}@enma.ai"
    name = "#{provider_name} Officer"
    avatar = clean_provider == "github" ? "https://avatars.githubusercontent.com/u/9919?v=4" : "https://lh3.googleusercontent.com/a/ACg8ocI"

    user = User.find_by(email_address: email) || User.create!(
      name: name,
      email_address: email,
      provider: clean_provider,
      uid: "#{clean_provider}_demo_#{SecureRandom.hex(4)}",
      avatar_url: avatar,
      role: :operator
    )

    login(user)
    flash[:notice] = "Signed in successfully with #{provider_name} SSO! Welcome, #{user.name}."
    redirect_to(session.delete(:return_to) || root_path)
  end

  def destroy
    logout
    flash[:notice] = "Successfully logged out."
    redirect_to root_path
  end
end
