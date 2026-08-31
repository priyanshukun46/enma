require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "should get root dashboard" do
    get root_url
    assert_response :success
    assert_select "h2", /Overview/
    assert_select "h3", /Predictive Risk Heatmap/
    assert_select "a[href=?]", map_path
  end
end
