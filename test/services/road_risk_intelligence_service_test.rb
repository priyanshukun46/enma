require "test_helper"

class RoadRiskIntelligenceServiceTest < ActiveSupport::TestCase
  setup do
    @road = Road.create!(
      name: "Trans-Arunachal Strategic Corridor",
      road_number: "NH-13-TEST",
      district: "Papum Pare",
      state: "Arunachal Pradesh",
      status: "accessible",
      risk_level: "low",
      road_condition: "good",
      risk_score: 20.0,
      weather_risk: 30.0,
      historical_risk: 50.0,
      incident_risk: 0.0,
      condition_risk: 20.0,
      geographic_risk: 60.0,
      length_km: 150.0,
      geometry_coordinates: [
        [27.0844, 93.6053],
        [27.3500, 93.7200],
        [27.5600, 93.8300]
      ]
    )
  end

  test "calculates weighted risk score using standard ENMA formula" do
    service = ResQWay::RoadRiskIntelligenceService.new(@road)
    result = service.calculate

    assert_operator result[:risk_score], :>=, 0.0
    assert_operator result[:risk_score], :<=, 100.0
    assert_includes %w[low moderate high critical], result[:risk_level]

    # Verify weights match configuration
    weights = Road::ENMA_RISK_WEIGHTS
    expected = (
      (result[:factors][:weather] * weights[:weather]) +
      (result[:factors][:historical] * weights[:historical]) +
      (result[:factors][:incidents] * weights[:incidents]) +
      (result[:factors][:condition] * weights[:condition]) +
      (result[:factors][:geographic] * weights[:geographic])
    ).round(1)

    assert_in_delta expected, result[:risk_score], 0.1
  end

  test "classifies risk correctly across all 4 tiers" do
    service = ResQWay::RoadRiskIntelligenceService.new(@road)

    assert_equal "low", service.classify_risk(15.0)
    assert_equal "low", service.classify_risk(25.0)
    assert_equal "moderate", service.classify_risk(35.0)
    assert_equal "moderate", service.classify_risk(50.0)
    assert_equal "high", service.classify_risk(65.0)
    assert_equal "high", service.classify_risk(75.0)
    assert_equal "critical", service.classify_risk(76.0)
    assert_equal "critical", service.classify_risk(100.0)
  end

  test "critical field incident within proximity significantly elevates road risk" do
    # Initial score
    service = ResQWay::RoadRiskIntelligenceService.new(@road)
    initial_res = service.calculate
    assert_equal 0.0, initial_res[:factors][:incidents]

    # Create critical landslide directly near road waypoint
    Incident.create!(
      incident_type: "landslide",
      severity: "critical",
      status: "verified",
      description: "Severe rockfall blocking transit along corridor curves.",
      latitude: 27.0850,
      longitude: 93.6060,
      location_name: "Corridor Km 42",
      reported_at: 10.minutes.ago
    )

    recalc_service = ResQWay::RoadRiskIntelligenceService.new(@road)
    recalc_res = recalc_service.calculate

    assert_operator recalc_res[:factors][:incidents], :>=, 90.0
    assert_operator recalc_res[:risk_score], :>, initial_res[:risk_score]
  end

  test "calculates edge cases: all risks zero and all risks maximum" do
    # All zero baseline
    @road.update!(
      weather_risk: 0.0,
      historical_risk: 0.0,
      incident_risk: 0.0,
      condition_risk: 0.0,
      geographic_risk: 0.0,
      road_condition: "excellent",
      state: "Tripura",
      geometry_coordinates: []
    )

    zero_service = ResQWay::RoadRiskIntelligenceService.new(@road)
    res_zero = zero_service.calculate
    assert_operator res_zero[:risk_score], :>=, 0.0
    assert_operator res_zero[:risk_score], :<=, 30.0

    # Max risk road
    @road.update!(
      weather_risk: 100.0,
      historical_risk: 100.0,
      incident_risk: 100.0,
      condition_risk: 100.0,
      geographic_risk: 100.0,
      road_condition: "critical"
    )

    max_service = ResQWay::RoadRiskIntelligenceService.new(@road)
    res_max = max_service.calculate
    assert_equal 100.0, res_max[:risk_score]
    assert_equal "critical", res_max[:risk_level]
  end

  test "calculate_and_update! updates road record and logs RoadRiskAssessment" do
    assert_difference("RoadRiskAssessment.count", 1) do
      @road.recalculate_risk!(trigger_source: "unit_test")
    end

    assessment = @road.risk_assessments.last
    assert_equal @road.risk_score, assessment.risk_score
    assert_equal "unit_test", assessment.trigger_source
    assert assessment.calculated_at.present?
  end

  test "RiskExplanationService provides explainable AI drivers from actual factors" do
    @road.update!(
      incident_risk: 85.0,
      weather_risk: 70.0,
      geographic_risk: 80.0,
      risk_level: "critical",
      risk_score: 82.0
    )

    explanation = @road.risk_explanation
    assert_equal @road.id, explanation[:road_id]
    assert_equal "critical", explanation[:risk_level]
    assert_operator explanation[:primary_factors].size, :>=, 2

    labels = explanation[:primary_factors].map { |f| f[:label] }
    assert_includes labels, "Incident Risk"
    assert_includes labels, "Weather Risk"
    assert_includes labels, "Geographic Risk"
    assert_includes explanation[:narrative_summary], "CRITICAL"
  end
end
