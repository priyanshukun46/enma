require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(
      name: "Super Admin",
      email_address: "super.admin@resqway.ai",
      password: "password123",
      role: :admin
    )

    @operator = User.create!(
      name: "Field Operator",
      email_address: "field.operator@resqway.ai",
      password: "password123",
      role: :operator
    )
  end

  test "unauthenticated user cannot access admin users" do
    get admin_users_url
    # require_admin redirects to dashboard_path, which will then redirect to login
    assert_redirected_to dashboard_url
  end

  test "operator cannot access admin users" do
    post login_url, params: { email_address: @operator.email_address, password: "password123" }
    get admin_users_url
    assert_redirected_to dashboard_url
    follow_redirect!
    assert_select "div", text: /Access denied/
  end

  test "admin can access admin users index" do
    post login_url, params: { email_address: @admin.email_address, password: "password123" }
    get admin_users_url
    assert_response :success
    assert_select "h2", "User Administration"
    assert_select "tbody tr", minimum: 2
  end

  test "admin can promote operator to admin" do
    post login_url, params: { email_address: @admin.email_address, password: "password123" }

    patch update_role_admin_user_url(@operator), params: { role: "admin" }
    assert_redirected_to admin_users_url

    @operator.reload
    assert @operator.admin?
  end

  test "admin cannot demote the last remaining admin" do
    post login_url, params: { email_address: @admin.email_address, password: "password123" }

    patch update_role_admin_user_url(@admin), params: { role: "operator" }
    assert_redirected_to admin_users_url
    follow_redirect!
    assert_select "div", text: /Cannot demote the last remaining administrator/

    @admin.reload
    assert @admin.admin?
  end
end
