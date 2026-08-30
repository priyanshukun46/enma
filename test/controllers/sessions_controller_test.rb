require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "Commander Singh",
      email_address: "singh@enma.ai",
      password: "password123",
      role: :operator
    )
  end

  test "should get new login page" do
    get login_url
    assert_response :success
    assert_select "h2", "ENMA AI"
    assert_select "input[name='email_address']"
    assert_select "input[name='password']"
  end

  test "should login with valid credentials and redirect" do
    post login_url, params: {
      email_address: "singh@enma.ai",
      password: "password123"
    }
    assert_redirected_to root_url
    assert_equal @user.id, session[:user_id]
    follow_redirect!
    assert_response :success
    assert_select "button", text: /Logout/
  end

  test "should reject invalid credentials" do
    post login_url, params: {
      email_address: "singh@enma.ai",
      password: "wrongpassword"
    }
    assert_response :unprocessable_entity
    assert_nil session[:user_id]
    assert_select "div", text: /Invalid email or password/
  end

  test "should logout via DELETE request, clear session, and show flash message" do
    # First login
    post login_url, params: {
      email_address: "singh@enma.ai",
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
end
