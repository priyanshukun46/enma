module ResQWay
  # ===========================================================================
  # ML Prediction Provider Interface (Strategy Pattern)
  #
  # Integrates Rails with the standalone Python FastAPI ML Prediction Service
  # ===========================================================================
  class MlPredictionProvider
    def self.predict_for(road)
      new.predict(road)
    end

    def predict(road)
      res = ResQWay::MlPredictionService.new(road).predict

      {
        disruption_probability: res[:disruption_probability],
        probability_percentage: res[:probability_percentage],
        predicted_risk_level: res[:risk_level],
        prediction_window_hours: res[:prediction_window_hours] || 24,
        is_ml_active: (res[:status] == "success"),
        model_version: res[:model_version],
        algorithm: res[:algorithm],
        top_factors: res[:top_factors],
        narrative: res[:narrative_explanation]
      }
    end
  end
end
