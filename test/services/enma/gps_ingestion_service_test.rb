require "test_helper"

class GpsIngestionServiceTest < ActiveSupport::TestCase
  setup do
    @vehicle = Vehicle.create!(
      registration_number: "AS-01-INGEST-1",
      vehicle_type: "Truck",
      status: "in_transit"
    )

    @shipment = Shipment.create!(
      vehicle: @vehicle,
      cargo_type: "medicine",
      priority: "high",
      origin_name: "Guwahati",
      origin_latitude: 26.1445,
      origin_longitude: 91.7362,
      destination_name: "Shillong",
      destination_latitude: 25.5788,
      destination_longitude: 91.8933,
      status: "in_transit",
      planned_route_geometry_json: [
        [26.1445, 91.7362], [25.8800, 91.8200], [25.5788, 91.8933]
      ],
      total_distance_km: 100.0
    )
  end

  test "successfully ingests GPS and updates vehicle and shipment progress" do
    service = Enma::GpsIngestionService.new({
      api_auth_token: @vehicle.api_auth_token,
      latitude: 25.8800,
      longitude: 91.8200,
      speed: 48.0,
      heading: 145.0,
      accuracy: 6.0,
      recorded_at: Time.current.iso8601
    })

    result = service.process

    assert result[:success]
    assert_equal @vehicle.id, result[:vehicle_id]

    @vehicle.reload
    assert_equal 25.8800, @vehicle.current_latitude
    assert_equal 48.0, @vehicle.current_speed

    @shipment.reload
    assert @shipment.progress_percentage > 20.0
    assert @shipment.enma_adjusted_eta.present?
  end

  test "detects route deviation and creates logistics alert" do
    # Deviate by sending coordinates far off the planned corridor
    service = Enma::GpsIngestionService.new({
      api_auth_token: @vehicle.api_auth_token,
      latitude: 26.5000, # ~40km away from corridor
      longitude: 92.5000,
      speed: 35.0,
      heading: 90.0,
      accuracy: 10.0,
      recorded_at: Time.current.iso8601
    })

    result = service.process

    assert result[:success]
    @shipment.reload
    assert @shipment.deviation_detected
    assert @shipment.deviation_distance_meters > 800.0

    alert = LogisticsAlert.find_by(shipment: @shipment, alert_type: "route_deviation")
    assert_not_nil alert
    assert_equal "critical", alert.severity
  end

  test "rejects invalid coordinates" do
    service = Enma::GpsIngestionService.new({
      api_auth_token: @vehicle.api_auth_token,
      latitude: 195.0, # invalid latitude
      longitude: 91.8200
    })

    result = service.process
    assert_not result[:success]
    assert_equal :unprocessable_entity, result[:status]
  end
end
