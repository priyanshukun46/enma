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

  test "login page should render Quick Demo Access buttons" do
    get login_url
    assert_response :success
    assert_select "button", text: /Admin Access/
    assert_select "button", text: /Operator Access/
  end

  test "should login via Quick Demo Access as Admin" do
    post login_url, params: {
      login: "admin",
      password: "password123"
    }
    assert_redirected_to dashboard_url
    assert_not_nil session[:user_id]
    admin = User.find(session[:user_id])
    assert_equal "admin", admin.username
    assert admin.admin?
    follow_redirect!
    assert_response :success
  end

  test "should login via Quick Demo Access as Operator" do
    post login_url, params: {
      login: "operator",
      password: "password123"
    }
    assert_redirected_to dashboard_url
    assert_not_nil session[:user_id]
    op = User.find(session[:user_id])
    assert_equal "operator", op.username
    assert op.operator?
    follow_redirect!
    assert_response :success
  end

  test "login page should not have application sidebar" do
    get login_url
    assert_response :success
    assert_select "aside", count: 0
  end
end
