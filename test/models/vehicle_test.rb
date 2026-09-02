require "test_helper"

class VehicleTest < ActiveSupport::TestCase
  test "validates required attributes and uniqueness of registration" do
    v1 = Vehicle.create!(registration_number: "AS-01-TEST-100", vehicle_type: "Truck", status: "available")
    assert v1.api_auth_token.present?

    v2 = Vehicle.new(registration_number: "AS-01-TEST-100", vehicle_type: "Truck")
    assert_not v2.valid?
  end

  test "updates position from gps telemetry" do
    v = Vehicle.create!(registration_number: "AS-01-TEST-200", vehicle_type: "Ambulance", status: "in_transit")
    v.update_position_from_gps!(26.1445, 91.7362, speed: 45.0, heading: 90.0)

    assert_equal 26.1445, v.current_latitude
    assert_equal 91.7362, v.current_longitude
    assert_equal 45.0, v.current_speed
    assert_equal 90.0, v.current_heading
    assert_not_nil v.last_location_at
  end
end
