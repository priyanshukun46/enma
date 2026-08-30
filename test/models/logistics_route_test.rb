require "test_helper"

class LogisticsRouteTest < ActiveSupport::TestCase
  setup do
    @origin = Location.create!(
      name: "Guwahati",
      latitude: 26.14,
      longitude: 91.73,
      accessibility_score: 95.0
    )
    @destination = Location.create!(
      name: "Shillong",
      latitude: 25.57,
      longitude: 91.89,
      accessibility_score: 90.0
    )
  end

  test "valid logistics route saves successfully" do
    route = LogisticsRoute.new(
      origin: @origin,
      destination: @destination,
      vehicle_type: "Truck",
      distance: 98.5,
      estimated_time: 2.5,
      risk_score: 18.0,
      route_type: "fastest",
      recommended: true
    )
    assert route.valid?
    assert route.save
  end

  test "rejects identical origin and destination" do
    route = LogisticsRoute.new(
      origin: @origin,
      destination: @origin,
      vehicle_type: "Truck",
      distance: 0.0,
      estimated_time: 0.0,
      risk_score: 10.0,
      route_type: "fastest"
    )
    assert_not route.valid?
    assert_includes route.errors[:destination_id], "cannot be the same as origin location"
  end

  test "validates route_type inclusion" do
    route = LogisticsRoute.new(
      origin: @origin,
      destination: @destination,
      vehicle_type: "Truck",
      distance: 50.0,
      estimated_time: 1.0,
      risk_score: 20.0,
      route_type: "invalid_type"
    )
    assert_not route.valid?
  end

  test "helpers return expected values" do
    route = LogisticsRoute.new(
      origin: @origin,
      destination: @destination,
      vehicle_type: "Ambulance",
      distance: 120.0,
      estimated_time: 3.5,
      risk_score: 45.0,
      route_type: "safest"
    )

    assert_equal "3h 30m", route.formatted_time
    assert_equal "MODERATE", route.risk_level
    assert_equal "Safest Route", route.route_type_display
  end
end
