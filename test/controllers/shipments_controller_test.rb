require "test_helper"

class ShipmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @origin = Location.create!(
      name: "Guwahati Hub",
      latitude: 26.1445,
      longitude: 91.7362,
      accessibility_score: 90.0
    )
    @destination = Location.create!(
      name: "Shillong Base",
      latitude: 25.5788,
      longitude: 91.8933,
      accessibility_score: 85.0
    )
    @vehicle = Vehicle.create!(
      registration_number: "AS-01-CTRL-TEST",
      vehicle_type: "Truck",
      status: "available"
    )
    @shipment = Shipment.create!(
      vehicle: @vehicle,
      cargo_type: "medicine",
      priority: "critical",
      origin: @origin,
      origin_name: @origin.name,
      origin_latitude: @origin.latitude,
      origin_longitude: @origin.longitude,
      destination: @destination,
      destination_name: @destination.name,
      destination_latitude: @destination.latitude,
      destination_longitude: @destination.longitude,
      status: "in_transit",
      total_distance_km: 100.0,
      planned_route_geometry_json: [[26.14, 91.73], [25.88, 91.82], [25.57, 91.89]]
    )
  end

  test "gets shipments dashboard index" do
    get shipments_url
    assert_response :success
    assert_select "h1", /Live Logistics/
    assert_select "div", text: /#{@shipment.tracking_number}/
  end

  test "shows shipment details and telemetry" do
    get shipment_url(@shipment)
    assert_response :success
    assert_select "h1", text: /#{@shipment.tracking_number}/
    assert_select "div[data-controller='shipment-map']"
  end

  test "runs simulation step on POST simulate" do
    post simulate_shipment_url(@shipment), params: { scenario: "normal_movement" }
    assert_redirected_to shipment_path(@shipment)
    follow_redirect!
    assert_response :success
  end

  test "renders live map view" do
    get live_map_shipments_url
    assert_response :success
    assert_select "h1", /Live Logistics Fleet Map/
  end
end
