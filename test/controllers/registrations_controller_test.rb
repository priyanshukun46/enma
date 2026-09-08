require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "should get sign up page" do
    get sign_up_url
    assert_response :success
    assert_select "h2", text: /ResQWay|ENMA AI/
    assert_select "input[name='user[name]']"
    assert_select "input[name='user[email_address]']"
    assert_select "input[name='user[password]']"
    assert_select "aside", count: 0
  end

  test "should create user and establish session" do
    assert_difference("User.count", 1) do
      post sign_up_url, params: {
        user: {
          name: "Dr. Deepa Das",
          email_address: "deepa.das@enma.ai",
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    new_user = User.last
    assert_equal "operator", new_user.role
    assert_equal new_user.id, session[:user_id]
    assert_redirected_to dashboard_url
  end

  test "should reject registration with mismatched password confirmation" do
    assert_no_difference("User.count") do
      post sign_up_url, params: {
        user: {
          name: "Dr. Deepa Das",
          email_address: "deepa.das@enma.ai",
          password: "password123",
          password_confirmation: "mismatched"
        }
      }
    end

    assert_response :unprocessable_entity
  end
end
