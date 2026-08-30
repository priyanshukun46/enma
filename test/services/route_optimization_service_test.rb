require "test_helper"

class RouteOptimizationServiceTest < ActiveSupport::TestCase
  setup do
    @guwahati = Location.create!(
      name: "Guwahati",
      latitude: 26.1445,
      longitude: 91.7362,
      road_quality: "excellent",
      rainfall_level: "low",
      landslide_risk: "low",
      accessibility_score: 95.0
    )

    @tawang = Location.create!(
      name: "Tawang",
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

  test "generates three distinct route strategies with multi-criteria scores" do
    service = RouteOptimizationService.new(origin: @guwahati, destination: @tawang, vehicle_type: "Truck")
    result = service.calculate

    routes = result[:routes]
    assert_not_nil routes[:fastest]
    assert_not_nil routes[:safest]
    assert_not_nil routes[:efficient]

    # Check that scores dimension hash exists
    [routes[:fastest], routes[:safest], routes[:efficient]].each do |r|
      assert_not_nil r[:scores][:safety]
      assert_not_nil r[:scores][:time]
      assert_not_nil r[:scores][:accessibility]
      assert_not_nil r[:scores][:overall_intelligence]
      assert r[:coordinates].size >= 2
    end

    # Safest has high safety score
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
  end
end
