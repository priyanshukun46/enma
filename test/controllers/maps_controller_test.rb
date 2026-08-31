require "test_helper"

class MapsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @road = Road.create!(
      name: "Guwahati-Shillong Expressway",
      road_number: "NH-06",
      district: "Ri-Bhoi",
      state: "Meghalaya",
      status: "moderate_risk",
      risk_score: 45.0,
      geometry_coordinates: [[26.1, 91.7], [25.5, 91.8]]
    )
  end

  test "should get map index successfully" do
    get map_url
    assert_response :success
    assert_select "h2", /Road Accessibility Intelligence Map/
    assert_select "div[data-controller='map']"
    assert_select "div[data-map-target='container']"
  end

  test "should filter map by state parameter" do
    get map_url(state: "Meghalaya")
    assert_response :success
  end

  test "should filter map by status parameter" do
    get map_url(status: "moderate_risk")
    assert_response :success
  end

  test "should return JSON telemetry payload" do
    get map_url, as: :json
    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("roads")
    assert json.key?("locations")
    assert json.key?("warehouses")
    assert json.key?("emergencies")
    assert json.key?("metrics")
    assert_operator json["metrics"]["total_roads"], :>=, 1
  end
end
