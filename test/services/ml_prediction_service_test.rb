require "test_helper"

class MlPredictionServiceTest < ActiveSupport::TestCase
  setup do
    @road = Road.create!(
      name: "NH-13 Trans-Arunachal",
      road_number: "NH-13-TEST",
      district: "Papum Pare",
      state: "Arunachal Pradesh",
      status: "accessible",
      risk_level: "high",
      road_condition: "poor",
      risk_score: 68.0,
      weather_risk: 75.0,
      historical_risk: 60.0,
      incident_risk: 50.0,
      condition_risk: 70.0,
      geographic_risk: 80.0,
      length_km: 150.0,
      geometry_coordinates: [[27.0, 93.6], [27.3, 93.7]]
    )
    @service = ResQWay::MlPredictionService.new(@road)
  end

  test "build_feature_payload constructs all 16 canonical ML features" do
    payload = @service.build_feature_payload

    assert_equal @road.id, payload[:road_id]
    assert_equal true, payload[:severe_weather_flag]
    assert payload.key?(:rainfall_last_1h)
    assert payload.key?(:rainfall_last_24h)
    assert payload.key?(:forecast_rainfall_6h)
    assert payload.key?(:forecast_rainfall_12h)
    assert payload.key?(:forecast_rainfall_24h)
    assert payload.key?(:historical_incident_count)
    assert payload.key?(:historical_landslide_count)
    assert payload.key?(:historical_flood_count)
    assert payload.key?(:previous_road_closures)
    assert payload.key?(:road_condition_score)
    assert payload.key?(:elevation)
    assert payload.key?(:slope)
    assert payload.key?(:recent_incident_count)
    assert payload.key?(:recent_incident_severity_score)
    assert payload.key?(:current_risk_score)
  end

  test "handles successful ML service prediction and persists record" do
    mock_response = {
      "road_id" => @road.id,
      "disruption_probability" => 0.824,
      "risk_level" => "critical",
      "prediction_window_hours" => 24,
      "model_version" => "1.0.0",
      "top_factors" => [
        { "feature" => "rainfall_last_24h", "importance" => "high", "label" => "🌧 24h Rainfall", "value" => 85.0 }
      ],
      "narrative_explanation" => "Critical disruption predicted.",
      "model_metadata" => { "algorithm" => "LogisticRegression" }
    }

    # Define singleton method for mock
    @service.define_singleton_method(:call_ml_api) do |_payload|
      mock_response
    end

    assert_difference -> { RoadDisruptionPrediction.count }, 1 do
      result = @service.predict

      assert_equal "success", result[:status]
      assert_equal 0.824, result[:disruption_probability]
      assert_equal "critical", result[:risk_level]
      assert_equal 24, result[:prediction_window_hours]
      assert_equal "1.0.0", result[:model_version]
    end
  end

  test "gracefully falls back when ML service is offline without raising exception" do
    @service.define_singleton_method(:call_ml_api) do |_payload|
      nil
    end

    assert_nothing_raised do
      result = @service.predict

      assert_includes %w[fallback cached], result[:status]
      assert result[:disruption_probability] > 0.0
      assert_not_nil result[:risk_level]
    end
  end

  test "road integrates with MlPredictionProvider" do
    provider_result = ResQWay::MlPredictionProvider.predict_for(@road)
    assert_not_nil provider_result[:prediction_window_hours]
    assert provider_result.key?(:disruption_probability)
  end
end
