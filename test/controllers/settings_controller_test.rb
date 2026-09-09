require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "Security Officer",
      email_address: "security@resqway.ai",
      password: "password123",
      password_confirmation: "password123",
      role: :operator
    )
    post login_url, params: { email_address: @user.email_address, password: "password123" }
  end

  test "should get settings show" do
    get settings_url
    assert_response :success
    assert_select "h2", /Security & Credentials Settings/
    assert_select "h3", /Connected Single Sign-On/
  end

  test "should connect Google SSO" do
    post connect_sso_settings_url, params: { provider: "google" }
    assert_redirected_to settings_url
    @user.reload
    assert_equal "google_oauth2", @user.provider
    assert_not_nil @user.uid
  end

  test "should connect GitHub SSO" do
    post connect_sso_settings_url, params: { provider: "github" }
    assert_redirected_to settings_url
    @user.reload
    assert_equal "github", @user.provider
    assert_not_nil @user.uid
  end

  test "should disconnect SSO when password exists" do
    @user.update!(provider: "google_oauth2", uid: "google_12345")
    delete disconnect_sso_settings_url
    assert_redirected_to settings_url
    @user.reload
    assert_nil @user.provider
    assert_nil @user.uid
  end
end
