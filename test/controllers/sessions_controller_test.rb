require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "Commander Singh",
      username: "commander_singh",
      email_address: "singh@resqway.ai",
      password: "password123",
      role: :operator
    )
  end

  test "should get new login page" do
    get login_url
    assert_response :success
    assert_select "h2", text: /ResQWay|ENMA AI/
    assert_select "input[name='login']"
    assert_select "input[name='password']"
  end

  test "should login with valid email credentials and redirect" do
    post login_url, params: {
      login: "singh@resqway.ai",
      password: "password123"
    }
    assert_redirected_to dashboard_url
    assert_equal @user.id, session[:user_id]
    follow_redirect!
    assert_response :success
    assert_select "button", text: /Logout|Sign Out/
  end

  test "should login with valid username credentials and redirect" do
    post login_url, params: {
      login: "commander_singh",
      password: "password123"
    }
    assert_redirected_to dashboard_url
    assert_equal @user.id, session[:user_id]
    follow_redirect!
    assert_response :success
    assert_select "button", text: /Logout|Sign Out/
  end

  test "should reject invalid credentials" do
    post login_url, params: {
      login: "singh@resqway.ai",
      password: "wrongpassword"
    }
    assert_response :unprocessable_entity
    assert_nil session[:user_id]
    assert_select "div", text: /Invalid username, email, or password/
  end

  test "should logout via DELETE request, clear session, and show flash message" do
    # First login
    post login_url, params: {
      login: "commander_singh",
      password: "password123"
    }
    assert_equal @user.id, session[:user_id]

    # Then logout via DELETE
    delete logout_url
    assert_redirected_to root_url
    assert_nil session[:user_id]
    follow_redirect!
    assert_response :success
    assert_select "div", text: /Successfully logged out/
  end

  test "should authenticate with Google SSO" do
    post demo_sso_login_url, params: { provider: "google" }
    assert_redirected_to dashboard_url
    assert_not_nil session[:user_id]
    user = User.find(session[:user_id])
    assert_equal "google_oauth2", user.provider
    follow_redirect!
    assert_response :success
    assert_select "div", text: /Signed in successfully with Google SSO/
  end

  test "should authenticate with GitHub SSO" do
    post demo_sso_login_url, params: { provider: "github" }
    assert_redirected_to dashboard_url
    assert_not_nil session[:user_id]
    user = User.find(session[:user_id])
    assert_equal "github", user.provider
    follow_redirect!
    assert_response :success
    assert_select "div", text: /Signed in successfully with GitHub SSO/
  end

  test "should authenticate via real OmniAuth Google callback" do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
      provider: "google_oauth2",
      uid: "google_uid_9988",
      info: {
        name: "Google Officer Roy",
        email: "roy.google@resqway.ai",
        image: "https://lh3.googleusercontent.com/avatar.png"
      }
    })

    Rails.application.env_config["devise.mapping"] = Devise.mappings[:user]
    Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:google_oauth2]

    get user_google_oauth2_omniauth_callback_url
    assert_redirected_to dashboard_url
    assert_not_nil session[:user_id]
    user = User.find(session[:user_id])
    assert_equal "roy.google@resqway.ai", user.email
    assert_equal "google_oauth2", user.provider
  end

  test "should authenticate via real OmniAuth GitHub callback" do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new({
      provider: "github",
      uid: "github_uid_4455",
      info: {
        name: "GitHub Developer Singh",
        email: "singh.github@resqway.ai",
        image: "https://avatars.githubusercontent.com/u/123?v=4"
      }
    })

    Rails.application.env_config["devise.mapping"] = Devise.mappings[:user]
    Rails.application.env_config["omniauth.auth"] = OmniAuth.config.mock_auth[:github]

    get user_github_omniauth_callback_url
    assert_redirected_to dashboard_url
    assert_not_nil session[:user_id]
    user = User.find(session[:user_id])
    assert_equal "singh.github@resqway.ai", user.email
    assert_equal "github", user.provider
  end

  test "login page should not have application sidebar" do
    get login_url
    assert_response :success
    assert_select "aside", count: 0
  end
end
