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
  end
end
