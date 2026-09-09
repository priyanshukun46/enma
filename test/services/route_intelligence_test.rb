require "test_helper"

class RouteIntelligenceTest < ActiveSupport::TestCase
  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    @guwahati = Location.create!(
      name: "Guwahati Central Hub",
      latitude: 26.1445,
      longitude: 91.7362,
      road_quality: "excellent",
      rainfall_level: "low",
      landslide_risk: "low",
      accessibility_score: 92.0
    )

    @tawang = Location.create!(
      name: "Tawang Sector Base",
      latitude: 27.5855,
      longitude: 91.8679,
      road_quality: "poor",
      rainfall_level: "high",
      landslide_risk: "critical",
      accessibility_score: 15.0
    )
  end

  teardown do
    Rails.cache = @original_cache
  end

  # =========================================================================
  # 1. Weather Exposure Scoring Tests
  # =========================================================================
  test "WeatherService samples representative route coordinates and computes weather exposure score" do
    coords = [
      [26.14, 91.73],
      [26.40, 91.75],
      [26.80, 91.80],
      [27.20, 91.85],
      [27.58, 91.86]
    ]

    weather = WeatherService.sample_corridor_weather(coords, fallback_location: @guwahati)

    assert_not_nil weather
    assert weather[:samples_count] >= 3
    assert weather[:weather_exposure_score] >= 0.0
    assert weather[:weather_exposure_score] <= 100.0
    assert_not_nil weather[:condition_summary]
    assert_includes ["live", "cached_live", "demo_fallback"], weather[:source]
  end

  test "WeatherService handles empty coordinates with fallback corridor data" do
    weather = WeatherService.sample_corridor_weather([], fallback_location: @guwahati)

    assert_equal 1, weather[:samples_count]
    assert_equal "demo_fallback", weather[:source]
    assert weather[:weather_exposure_score] > 0.0
  end

  # =========================================================================
  # 2. Environmental Risk & Accessibility Scoring Tests
  # =========================================================================
  test "calculates environmental risk combining weather, terrain, and active emergency proximity" do
    service = RouteOptimizationService.new(origin: @guwahati, destination: @tawang, vehicle_type: "Truck")
    result = service.calculate

    routes = result[:routes]
    assert_not_nil routes[:fastest]
    assert_not_nil routes[:safest]
    assert_not_nil routes[:balanced]

    [routes[:fastest], routes[:safest], routes[:balanced]].each do |r|
      # Scores in 0..100 range
      assert r[:risk_score] >= 0.0 && r[:risk_score] <= 100.0
      assert r[:accessibility_score] >= 0.0 && r[:accessibility_score] <= 100.0
      assert r[:efficiency_score] >= 0.0 && r[:efficiency_score] <= 100.0
      assert r[:overall_score] >= 0.0 && r[:overall_score] <= 100.0

      # Positive or negative factors populated
      assert (r[:positive_factors].size + r[:negative_factors].size) > 0
    end
  end

  # =========================================================================
  # 3. Route Classification Tests
  # =========================================================================
  test "correctly classifies routes into FASTEST, SAFEST, and BALANCED" do
    service = RouteOptimizationService.new(origin: @guwahati, destination: @tawang, vehicle_type: "Emergency Vehicle")
    result = service.calculate

    routes = result[:routes]
    fastest = routes[:fastest]
    safest = routes[:safest]
    balanced = routes[:balanced]

    assert_equal "fastest", fastest[:type]
    assert_equal "safest", safest[:type]
    assert_equal "balanced", balanced[:type]

    # Fastest has the lowest or equal duration
    assert fastest[:duration_minutes] <= safest[:duration_minutes]
    # Safest has the lowest or equal environmental risk
    assert safest[:risk_score] <= fastest[:risk_score]
  end

  # =========================================================================
  # 4. Recommendation Engine & Safety Gating Tests
  # =========================================================================
  test "recommendation engine applies safety gating when fastest route is hazardous" do
    Emergency.create!(
      title: "Active Bhalukpong Landslide Disaster",
      emergency_type: "Landslide",
      severity: "Critical",
      status: "Active",
      latitude: 27.01,
      longitude: 91.82,
      affected_radius: 50.0,
      location: @guwahati
    )

    service = RouteOptimizationService.new(origin: @guwahati, destination: @tawang, vehicle_type: "Truck")
    result = service.calculate

    rec = result[:recommendation]
    assert_not_nil rec[:recommended_type]
    # When severe disaster intersection occurs on the fastest route, ResQWay does not choose the fatal route
    assert_includes [:safest, :balanced], rec[:recommended_type]
    assert rec[:reasons].any?
    assert rec[:confidence_percentage] >= 75
    assert_not_nil rec[:trade_off]
  end

  # =========================================================================
  # 5. Explainable Factors Generation Tests
  # =========================================================================
  test "generates distinct positive and negative factors for explainability" do
    service = RouteOptimizationService.new(origin: @guwahati, destination: @tawang, vehicle_type: "Truck")
    result = service.calculate

    safest_route = result[:routes][:safest]
    assert safest_route[:positive_factors].any? { |f| f.start_with?("✓") }

    fastest_route = result[:routes][:fastest]
    assert (fastest_route[:positive_factors].any? || fastest_route[:negative_factors].any?)
  end

  # =========================================================================
  # 6. Fallback Behavior Tests
  # =========================================================================
  test "maintains full operation with demo fallback when weather and routing APIs fail" do
    service = RouteOptimizationService.new(origin: @guwahati, destination: @tawang, vehicle_type: "Ambulance")

    original_osrm = RoutingService.instance_method(:fetch_osrm_routes)
    original_weather = WeatherService.instance_method(:fetch_from_api)

    begin
      RoutingService.define_method(:fetch_osrm_routes) { |*| raise Net::ReadTimeout, "OSRM Timeout" }
      WeatherService.define_method(:fetch_from_api) { |*| raise Net::ReadTimeout, "Weather API Timeout" }

      result = service.calculate

      assert_not_nil result[:routes]
      assert result[:routes][:fastest][:coordinates].any?
      assert_equal true, result[:fallback_used]
      assert_not_nil result[:recommendation][:recommended_type]
    ensure
      RoutingService.define_method(:fetch_osrm_routes, original_osrm)
      WeatherService.define_method(:fetch_from_api, original_weather)
    end
  end
end
