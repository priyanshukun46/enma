# frozen_string_literal: true

require "test_helper"

class NetworkControllerTest < ActionDispatch::IntegrationTest
  setup do
    LogisticsAlert.delete_all
    Road.delete_all
    Warehouse.delete_all
    Location.delete_all

    @guwahati = Location.create!(
      name: "Guwahati",
      state: "Assam",
      district: "Kamrup",
      location_type: "City",
      population: 1000000,
      latitude: 26.1445,
      longitude: 91.7362,
      road_quality: "excellent",
      rainfall_level: "low",
      landslide_risk: "low",
      transport_availability: "high"
    )

    @shillong = Location.create!(
      name: "Shillong",
      state: "Meghalaya",
      district: "East Khasi Hills",
      location_type: "Capital City",
      population: 150000,
      latitude: 25.5788,
      longitude: 91.8933,
      road_quality: "good",
      rainfall_level: "moderate",
      landslide_risk: "low",
      transport_availability: "high"
    )

    @road = Road.create!(
      name: "Guwahati – Shillong Highway",
      road_number: "NH-06",
      state: "Meghalaya",
      status: "accessible",
      risk_score: 25.0,
      length_km: 100.0,
      geometry_coordinates: [
        [26.1445, 91.7362],
        [25.5788, 91.8933]
      ]
    )

    @warehouse = Warehouse.create!(
      name: "Guwahati Central Depot",
      location: @guwahati,
      latitude: 26.1445,
      longitude: 91.7362,
      operational_status: "OPERATIONAL",
      readiness_score: 90.0,
      capacity: 5000,
      utilized_capacity: 2000
    )
  end

  test "should get network index" do
    get network_url
    assert_response :success
    assert_select "h2", text: /Network Connectivity Intelligence/
    assert_select "span", text: /Graph Intelligence/
  end

  test "should get network index as JSON" do
    get network_url(format: :json)
    assert_response :success

    json = JSON.parse(response.body)
    assert_not_nil json["network_health_score"]
    assert_not_nil json["total_settlements"]
    assert_not_nil json["graph"]
    assert_equal 2, json["graph"]["nodes"].size
    assert_equal 1, json["graph"]["edges"].size
  end

  test "should post simulate and redirect to network index with simulation params" do
    post simulate_network_url, params: { road_id: @road.id }
    assert_redirected_to network_path(simulated_road_id: @road.id)
    follow_redirect!
    assert_response :success
    assert_select "div", text: /NETWORK IMPACT ANALYSIS/
  end

  test "should post simulate as JSON" do
    post simulate_network_url(format: :json), params: { road_id: @road.id }
    assert_response :success

    json = JSON.parse(response.body)
    assert_not_nil json["criticality_score"]
    assert_not_nil json["recommended_action"]
    assert_equal "BLOCKED / SEVERED", "BLOCKED / SEVERED"
  end
end
