require "test_helper"

class Api::V1::VehicleLocationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @vehicle = Vehicle.create!(
      registration_number: "AS-01-API-TEST",
      vehicle_type: "Emergency Vehicle",
      status: "in_transit"
    )

    @shipment = Shipment.create!(
      vehicle: @vehicle,
      cargo_type: "medicine",
      priority: "emergency",
      origin_name: "Guwahati",
      origin_latitude: 26.1445,
      origin_longitude: 91.7362,
      destination_name: "Shillong",
      destination_latitude: 25.5788,
      destination_longitude: 91.8933,
      status: "in_transit",
      total_distance_km: 100.0
    )
  end

  test "ingests GPS with Bearer token header" do
    post api_v1_vehicle_locations_url, params: {
      latitude: 25.9000,
      longitude: 91.8000,
      speed: 52.0,
      heading: 150.0,
      accuracy: 5.0,
      recorded_at: Time.current.iso8601
    }, headers: { "Authorization" => "Bearer #{@vehicle.api_auth_token}" }, as: :json

    assert_response :created
    data = JSON.parse(response.body)
    assert data["success"]
    assert_equal @vehicle.id, data["vehicle_id"]
  end

  test "rejects unauthorized request with missing token" do
    post api_v1_vehicle_locations_url, params: {
      latitude: 25.9000,
      longitude: 91.8000
    }, as: :json

    assert_response :unauthorized
  end
end
