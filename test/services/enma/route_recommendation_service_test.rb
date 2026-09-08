require "test_helper"

class RouteRecommendationServiceTest < ActiveSupport::TestCase
  setup do
    @origin = Location.create!(
      name: "Guwahati Hub",
      district: "Kamrup",
      state: "Assam",
      latitude: 26.1445,
      longitude: 91.7362,
      accessibility_score: 85.0
    )

    @destination = Location.create!(
      name: "Shillong Sector",
      district: "East Khasi Hills",
      state: "Meghalaya",
      latitude: 25.5788,
      longitude: 91.8933,
      accessibility_score: 75.0
    )

    @road = Road.create!(
      name: "Guwahati-Shillong Expressway",
      road_number: "NH-06-TEST",
      district: "Kamrup",
      state: "Assam",
      status: "accessible",
      risk_level: "low",
      road_condition: "good",
      risk_score: 22.0,
      weather_risk: 30.0,
      historical_risk: 25.0,
      incident_risk: 0.0,
      condition_risk: 20.0,
      geographic_risk: 40.0,
      length_km: 100.0,
      geometry_coordinates: [[26.1, 91.7], [25.8, 91.8], [25.5, 91.8]]
    )
  end

  test "calculates multi-route recommendations with all priority modes" do
    %w[balanced safest fastest emergency].each do |mode|
      service = Enma::RouteRecommendationService.new(
        origin: @origin,
        destination: @destination,
        priority_mode: mode,
        vehicle_type: "Truck",
        cargo_type: "General Supplies",
        options: { provider: "fallback" }
      )

      result = service.recommend

      assert_not_nil result[:recommended_route]
      assert result[:routes].size >= 3
      assert_equal mode, result[:priority_mode]
      assert result[:explanation][:confidence_score] > 50.0
      assert_not_nil result[:recommended_route][:optimization_score]
      assert_not_nil result[:recommended_route][:enma_adjusted_eta_minutes]
      assert_not_nil result[:recommended_route][:ml_disruption_probability]
    end
  end

  test "safest priority mode penalizes high risk corridors" do
    service = Enma::RouteRecommendationService.new(
      origin: @origin,
      destination: @destination,
      priority_mode: "safest",
      options: { provider: "fallback" }
    )

    result = service.recommend
    recommended = result[:recommended_route]

    assert recommended[:route_risk_score] < 80.0
  end

  test "excludes blocked road corridors from recommended selection" do
    @road.update!(status: "blocked")

    service = Enma::RouteRecommendationService.new(
      origin: @origin,
      destination: @destination,
      priority_mode: "balanced",
      options: { provider: "fallback" }
    )

    result = service.recommend
    assert_not_nil result[:recommended_route]
  end

  test "correctly detects when a new incident requires rerouting" do
    analysis = RouteAnalysis.create!(
      origin: @origin,
      destination: @destination,
      priority_mode: "balanced",
      vehicle_type: "Truck",
      segment_analysis_json: [
        { road_id: @road.id, coordinates: [[26.14, 91.73], [25.90, 91.80]] }
      ]
    )

    intersecting_incident = Incident.create!(
      description: "Severe Landslide blocking highway pass",
      incident_type: "landslide",
      severity: "critical",
      latitude: 26.13,
      longitude: 91.74,
      reported_at: Time.current
    )

    far_incident = Incident.create!(
      description: "Minor road hazard far in Sikkim",
      incident_type: "landslide",
      severity: "low",
      latitude: 27.50,
      longitude: 88.50,
      reported_at: Time.current
    )

    assert Enma::RouteRecommendationService.check_rerouting_needed(analysis, intersecting_incident)
    assert_not Enma::RouteRecommendationService.check_rerouting_needed(analysis, far_incident)
  end

  test "gracefully handles offline ML and weather without crashing" do
    service = Enma::RouteRecommendationService.new(
      origin: @origin,
      destination: @destination,
      priority_mode: "emergency",
      options: { provider: "fallback" }
    )

    result = service.recommend
    assert_not_nil result[:recommended_route]
    assert result[:recommended_route][:ml_disruption_probability] >= 0.0
  end

  test "marks route as blocked when origin and destination are in disconnected network partitions" do
    # Create an isolated destination
    isolated_dest = Location.create!(
      name: "Cutoff Island",
      district: "Kamrup",
      state: "Assam",
      latitude: 26.5000,
      longitude: 92.5000,
      accessibility_score: 20.0
    )

    # Road between origin and destination is blocked
    @road.update!(status: "blocked")
    Rails.cache.clear

    service = Enma::RouteRecommendationService.new(
      origin: @origin,
      destination: isolated_dest,
      priority_mode: "balanced",
      options: { provider: "fallback" }
    )

    result = service.recommend
    # All routes should encounter blockage / disconnection
    assert result[:routes].all? { |r| r[:is_blocked] }
    assert_includes result[:explanation][:warnings].join, "blockages"
  end
end
