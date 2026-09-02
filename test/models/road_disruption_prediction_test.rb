require "test_helper"

class RoadDisruptionPredictionTest < ActiveSupport::TestCase
  setup do
    @road = Road.create!(
      name: "NH-229 Sela Pass",
      road_number: "NH-229-TEST",
      district: "West Kameng",
      state: "Arunachal Pradesh",
      status: "accessible",
      risk_level: "high",
      road_condition: "moderate",
      risk_score: 65.0,
      weather_risk: 75.0,
      historical_risk: 80.0,
      incident_risk: 60.0,
      condition_risk: 50.0,
      geographic_risk: 90.0,
      length_km: 180.0,
      geometry_coordinates: [[27.5, 92.1], [27.6, 92.2]]
    )

    @prediction = RoadDisruptionPrediction.new(
      road: @road,
      disruption_probability: 0.824,
      risk_level: "critical",
      prediction_window_hours: 24,
      model_version: "1.0.0",
      algorithm: "LogisticRegression",
      status: "success",
      narrative_explanation: "High risk of road disruption due to heavy rainfall.",
      top_factors_json: [
        { feature: "rainfall_last_24h", importance: "high", label: "🌧 24h Rainfall", value: 85.0 }
      ],
      input_snapshot_json: { rainfall_last_24h: 85.0 },
      predicted_at: Time.current
    )
  end

  test "should be valid with valid attributes" do
    assert @prediction.valid?
  end

  test "should calculate probability percentage" do
    assert_equal 82.4, @prediction.probability_percentage
  end

  test "should require disruption_probability within 0.0 and 1.0" do
    @prediction.disruption_probability = 1.5
    assert_not @prediction.valid?

    @prediction.disruption_probability = -0.1
    assert_not @prediction.valid?
  end

  test "should require valid risk level" do
    @prediction.risk_level = "invalid_level"
    assert_not @prediction.valid?
  end

  test "should return top factors with indifferent access" do
    @prediction.save!
    assert_equal "high", @prediction.top_factors.first[:importance]
    assert_equal "🌧 24h Rainfall", @prediction.top_factors.first["label"]
  end
end
