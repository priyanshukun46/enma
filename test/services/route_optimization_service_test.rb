require "test_helper"

class RouteOptimizationServiceTest < ActiveSupport::TestCase
  setup do
    @guwahati = Location.create!(
      name: "Guwahati Hub",
      latitude: 26.1445,
      longitude: 91.7362,
      road_quality: "excellent",
      rainfall_level: "low",
      landslide_risk: "low",
      accessibility_score: 95.0
    )

    @tawang = Location.create!(
      name: "Tawang Post",
      latitude: 27.5855,
      longitude: 91.8679,
      road_quality: "poor",
      rainfall_level: "high",
      landslide_risk: "critical",
      accessibility_score: 10.0
    )
  end

  test "calculates positive Haversine distance between two coordinates" do
    service = RouteOptimizationService.new(origin: @guwahati, destination: @tawang, vehicle_type: "Truck")
    distance = service.calculate_haversine_distance(@guwahati.latitude, @guwahati.longitude, @tawang.latitude, @tawang.longitude)

    assert distance > 140.0
    assert distance < 200.0
  end

  test "generates distinct FASTEST, SAFEST, and BALANCED route strategies with multi-criteria scores" do
    service = RouteOptimizationService.new(origin: @guwahati, destination: @tawang, vehicle_type: "Truck")
    result = service.calculate

    routes = result[:routes]
    assert_not_nil routes[:fastest]
    assert_not_nil routes[:safest]
    assert_not_nil routes[:balanced]

    [routes[:fastest], routes[:safest], routes[:balanced]].each do |r|
      assert r[:risk_score] >= 0.0 && r[:risk_score] <= 100.0
      assert r[:accessibility_score] >= 0.0 && r[:accessibility_score] <= 100.0
      assert r[:efficiency_score] >= 0.0 && r[:efficiency_score] <= 100.0
      assert r[:overall_score] >= 0.0 && r[:overall_score] <= 100.0

      assert_not_nil r[:scores][:safety]
      assert_not_nil r[:scores][:time]
      assert_not_nil r[:scores][:accessibility]
      assert_not_nil r[:scores][:efficiency]
      assert_not_nil r[:scores][:overall_score]
      assert r[:geometry].size >= 2
    end

    # Safest has highest safety score (lowest risk)
    assert routes[:safest][:scores][:safety] >= routes[:fastest][:scores][:safety]
  end

  test "raises ArgumentError when origin and destination are identical" do
    assert_raises(ArgumentError) do
      RouteOptimizationService.new(origin: @guwahati, destination: @guwahati).calculate
    end
  end

  test "generates dynamic explainable recommendation, trade-off, and confidence score" do
    service = RouteOptimizationService.new(origin: @guwahati, destination: @tawang, vehicle_type: "Ambulance")
    result = service.calculate

    rec = result[:recommendation]
    assert_not_nil rec[:recommended_type]
    assert rec[:confidence_percentage] >= 75
    assert rec[:reasons].any?
    assert_not_nil rec[:trade_off]
    assert rec[:trade_off].include?("recommended")
  end

  test "supports different vehicle profiles with customized weights" do
    amb_service = RouteOptimizationService.new(origin: @guwahati, destination: @tawang, vehicle_type: "Ambulance")
    truck_service = RouteOptimizationService.new(origin: @guwahati, destination: @tawang, vehicle_type: "Truck")

    assert_equal 60.0, amb_service.send(:vehicle_profile)[:base_speed]
    assert_equal 42.0, truck_service.send(:vehicle_profile)[:base_speed]
  end
end
