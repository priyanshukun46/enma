require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "Reset Tester",
      email_address: "reset.test@enma.ai",
      password: "password123"
    )
  end

  test "should get password reset request page" do
    get new_password_url
    assert_response :success
    assert_select "h2", "Reset Password"
  end

  test "should request reset token and redirect with notice" do
    post passwords_url, params: { email_address: @user.email_address }
    assert_redirected_to login_url
    follow_redirect!
    assert_response :success
    assert_select "div", text: /If an account matches/
  end

  test "should update password with valid token and log user in" do
    token = @user.generate_token_for(:password_reset)

    get edit_password_url(token)
    assert_response :success
    assert_select "h2", "Set New Password"

    patch password_url(token), params: {
      password: "newpassword123",
      password_confirmation: "newpassword123"
    }

    assert_redirected_to dashboard_url
    assert_equal @user.id, session[:user_id]

    @user.reload
    assert @user.authenticate("newpassword123")
  end
end
