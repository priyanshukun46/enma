require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "should get root dashboard" do
    get root_url
    assert_response :success
    assert_select "h2", "Good Morning, Administrator"
    assert_select "h3", "Critical Accessibility Zones"
    assert_select "a[href=?]", accessibility_path
  end
end
