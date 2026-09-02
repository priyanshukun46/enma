require "test_helper"

class ShipmentTest < ActiveSupport::TestCase
  setup do
    @vehicle = Vehicle.create!(registration_number: "AS-01-SHP-999", vehicle_type: "Truck", status: "in_transit")
    @shipment = Shipment.create!(
      vehicle: @vehicle,
      cargo_type: "medicine",
      priority: "critical",
      origin_name: "Guwahati Hub",
      origin_latitude: 26.1445,
      origin_longitude: 91.7362,
      destination_name: "Shillong Base",
      destination_latitude: 25.5788,
      destination_longitude: 91.8933,
      status: "in_transit",
      total_distance_km: 100.0
    )
  end

  test "generates tracking number and formats delay correctly" do
    assert @shipment.tracking_number.start_with?("ENMA-TRK-")
    assert_equal "On Schedule", @shipment.formatted_delay

    @shipment.update!(delay_minutes: 35)
    assert_equal "+35 min delay", @shipment.formatted_delay
  end
end
