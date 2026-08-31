module Enma
  # ===========================================================================
  # ML Prediction Provider Interface (Strategy Pattern)
  #
  # Current: NullMlProvider (Rule-Based Hybrid Engine baseline)
  # Future: PythonMlProvider / FastApiMlProvider (Seamlessly pluggable)
  # ===========================================================================
  class MlPredictionProvider
    def predict(road_data)
      # Baseline interface returning nil ML factors until external ML service is attached
      {
        disruption_probability: nil,
        confidence_score: nil,
        predicted_risk_level: nil,
        prediction_window_hours: 12,
        is_ml_active: false
      }
    end
  end
end
