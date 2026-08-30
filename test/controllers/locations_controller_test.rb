require "test_helper"

class LocationsControllerTest < ActionDispatch::IntegrationTest
  test "should get locations index" do
    get locations_url
    assert_response :success
    assert_select "h2", "All Locations"
  end
end
