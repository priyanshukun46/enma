require "test_helper"

class MapsControllerTest < ActionDispatch::IntegrationTest
  test "should get maps index with accessibility data" do
    get map_url
    assert_response :success
    assert_select "h2", "North East Accessibility Intelligence Map"
    assert_select "div[data-controller='map']"
  end
end
