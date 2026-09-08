require "test_helper"

class RoutesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @origin = Location.create!(
      name: "Guwahati",
      latitude: 26.1445,
      longitude: 91.7362,
      road_quality: "excellent",
      rainfall_level: "low",
      landslide_risk: "low",
      accessibility_score: 95.0
    )

    @destination = Location.create!(
      name: "Shillong",
      latitude: 25.5788,
      longitude: 91.8933,
      road_quality: "good",
      rainfall_level: "moderate",
      landslide_risk: "low",
      accessibility_score: 90.0
    )
  end

  test "should get routes index" do
    get routes_url
    assert_response :success
    assert_select "h2", /Multi-Route Navigation/
    assert_select "select[name='origin_id']"
    assert_select "select[name='destination_id']"
    assert_select "select[name='vehicle_type']"
  end

  test "should calculate routes on valid POST and render results" do
    assert_difference("LogisticsRoute.count", 4) do
      post calculate_routes_url, params: {
        origin_id: @origin.id,
        destination_id: @destination.id,
        vehicle_type: "Ambulance"
      }
    end

    assert_response :success
    assert_select "div[data-controller='route-planner-map']"
    assert_select "h3", /Why (ResQWay|ENMA AI) Recommends This Route/
  end

  test "should return JSON results on calculate with json format" do
    post calculate_routes_url, params: {
      origin_id: @origin.id,
      destination_id: @destination.id,
      vehicle_type: "Truck"
    }, as: :json

    assert_response :success
    data = JSON.parse(response.body)
    assert_not_nil data["routes"]
    assert_not_nil data["recommendation"]
  end

  test "should reject identical origin and destination" do
    assert_no_difference("LogisticsRoute.count") do
      post calculate_routes_url, params: {
        origin_id: @origin.id,
        destination_id: @origin.id,
        vehicle_type: "Truck"
      }
    end

    assert_response :unprocessable_entity
    assert_select "div", text: /Origin and Destination cannot be the same location/
  end

  test "should reject missing parameters" do
    assert_no_difference("LogisticsRoute.count") do
      post calculate_routes_url, params: {
        origin_id: "",
        destination_id: "",
        vehicle_type: "Truck"
      }
    end

    assert_response :unprocessable_entity
    assert_select "div", text: /Please select both an Origin and a Destination location/
  end
end
