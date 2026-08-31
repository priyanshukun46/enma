require "test_helper"

class RoadRiskAssessmentTest < ActiveSupport::TestCase
  setup do
    @road = Road.create!(
      name: "Sela Pass Corridor",
      road_number: "NH-229-TEST",
      district: "Tawang",
      state: "Arunachal Pradesh",
      status: "accessible",
      risk_level: "low",
      road_condition: "good",
      risk_score: 15.0,
      length_km: 80.0
    )
  end

  test "valid assessment persists with all intelligence metrics" do
    assessment = @road.risk_assessments.new(
      risk_score: 68.5,
      risk_level: "high",
      weather_risk: 60.0,
      historical_risk: 75.0,
      incident_risk: 80.0,
      condition_risk: 50.0,
      geographic_risk: 70.0,
      trigger_source: "incident_reported",
      calculated_at: Time.current,
      factors_breakdown_json: { weather: 60, historical: 75, incidents: 80, condition: 50, geographic: 70 }
    )

    assert assessment.valid?
    assert assessment.save
    assert_equal 68.5, assessment.risk_score
    assert_equal "high", assessment.risk_level
    assert_equal 60, assessment.factors[:weather]
  end

  test "validates risk_score presence and range" do
    assessment = RoadRiskAssessment.new(road: @road, risk_score: 150.0, calculated_at: Time.current)
    assert_not assessment.valid?
    assert_includes assessment.errors[:risk_score], "must be less than or equal to 100.0"
  end
end
