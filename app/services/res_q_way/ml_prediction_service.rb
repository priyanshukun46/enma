require "net/http"
require "json"
require "uri"

module ResQWay
  class MlPredictionService
    DEFAULT_SERVICE_URL = "http://127.0.0.1:8000"
    DEFAULT_TIMEOUT_SECONDS = 2.0

    attr_reader :road, :service_url, :timeout

    def initialize(road_or_data, service_url: nil, timeout: nil)
      if road_or_data.is_a?(Road)
        @road = road_or_data
      elsif road_or_data.is_a?(Hash)
        r_id = road_or_data[:road_id] || road_or_data["road_id"]
        @road = (r_id ? Road.find_by(id: r_id) : nil) || OpenStruct.new(
          id: r_id || 0,
          road_number: road_or_data[:road_number] || "CORRIDOR",
          state: road_or_data[:state] || "Assam",
          risk_score: (road_or_data[:calculated_score] || road_or_data[:risk_score] || 20.0).to_f,
          weather_risk: (road_or_data[:weather_risk] || 20.0).to_f,
          historical_risk: (road_or_data[:historical_risk] || 20.0).to_f,
          incident_risk: (road_or_data[:incident_risk] || 0.0).to_f,
          condition_risk: (road_or_data[:condition_risk] || 20.0).to_f,
          geographic_risk: (road_or_data[:geographic_risk] || 20.0).to_f
        )
      else
        @road = road_or_data
      end

      @service_url = service_url || ENV["RESQWAY_ML_SERVICE_URL"].presence || DEFAULT_SERVICE_URL
      @timeout = timeout || ENV["RESQWAY_ML_TIMEOUT"].to_f.nonzero? || DEFAULT_TIMEOUT_SECONDS
    end

    def self.predict_for(road)
      new(road).predict
    end

    def self.predict_network
      Road.find_each do |road|
        new(road).predict
      rescue StandardError => e
        Rails.logger.warn("[ResQWay ML] Network prediction error for road #{road.id}: #{e.message}")
      end
    end

    def predict
      payload = build_feature_payload
      response_data = call_ml_api(payload)

      if response_data && response_data["disruption_probability"].present?
        record_successful_prediction(payload, response_data)
      else
        record_fallback_prediction(payload, "ML service unavailable or invalid response")
      end
    rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, Errno::EHOSTUNREACH => e
      Rails.logger.warn("[ResQWay ML] Service connection issue at #{service_url}: #{e.message}")
      record_fallback_prediction(payload, "ML prediction service offline (#{e.class.name})")
    rescue StandardError => e
      Rails.logger.error("[ResQWay ML] Unexpected prediction error: #{e.message}\n#{e.backtrace&.first(3)&.join("\n")}")
      record_fallback_prediction(payload, "Inference error: #{e.message}")
    end

    def build_feature_payload
      nearby_incidents = find_recent_incidents
      peak_severity = nearby_incidents.map(&:severity_score).max || 0.0

      # Extract terrain attributes or sensible defaults
      elev = extract_elevation
      slope_deg = extract_slope

      w_risk = (road.respond_to?(:weather_risk) ? road.weather_risk : 20.0).to_f
      h_risk = (road.respond_to?(:historical_risk) ? road.historical_risk : 20.0).to_f
      c_risk = (road.respond_to?(:condition_risk) ? road.condition_risk : 20.0).to_f
      r_score = (road.respond_to?(:risk_score) ? road.risk_score : 20.0).to_f

      {
        road_id: road.id || 0,
        rainfall_last_1h: [w_risk * 0.35, 100.0].min.round(1),
        rainfall_last_24h: [w_risk * 1.25, 250.0].min.round(1),
        forecast_rainfall_6h: [w_risk * 0.40, 100.0].min.round(1),
        forecast_rainfall_12h: [w_risk * 0.70, 150.0].min.round(1),
        forecast_rainfall_24h: [w_risk * 1.10, 220.0].min.round(1),
        severe_weather_flag: w_risk >= 70.0,
        historical_incident_count: (h_risk / 8.0).round,
        historical_landslide_count: (h_risk / 12.0).round,
        historical_flood_count: (h_risk / 20.0).round,
        previous_road_closures: (h_risk / 25.0).round,
        road_condition_score: c_risk.round(1),
        elevation: elev.round(1),
        slope: slope_deg.round(1),
        recent_incident_count: nearby_incidents.size,
        recent_incident_severity_score: peak_severity.round(1),
        current_risk_score: r_score.round(1)
      }
    end

    private

    def call_ml_api(payload)
      uri = URI.parse("#{service_url.chomp('/')}/predict")
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = timeout
      http.read_timeout = timeout

      request = Net::HTTP::Post.new(uri.request_uri, { "Content-Type" => "application/json" })
      request.body = payload.to_json

      response = http.request(request)

      if response.is_a?(Net::HTTPSuccess)
        JSON.parse(response.body)
      else
        Rails.logger.warn("[ResQWay ML] HTTP #{response.code} received from #{uri}: #{response.body}")
        nil
      end
    end

    def record_successful_prediction(payload, response_data)
      prob = response_data["disruption_probability"].to_f.clamp(0.0, 1.0)
      r_level = response_data["risk_level"] || "low"
      factors = response_data["top_factors"] || []
      narrative = response_data["narrative_explanation"] || "ML prediction generated."
      model_ver = response_data["model_version"] || "1.0.0"
      algo = response_data.dig("model_metadata", "algorithm") || "LogisticRegression"

      # Persist prediction history if road is ActiveRecord model
      prediction = nil
      if road.is_a?(Road) && road.persisted?
        prediction = road.disruption_predictions.create!(
          disruption_probability: prob,
          risk_level: r_level,
          prediction_window_hours: response_data["prediction_window_hours"] || 24,
          model_version: model_ver,
          algorithm: algo,
          status: "success",
          top_factors_json: factors,
          input_snapshot_json: payload,
          narrative_explanation: narrative,
          predicted_at: Time.current
        )

        # Update road fast-lookup cache columns
        road.update_columns(
          ml_disruption_probability: prob,
          ml_confidence_score: calculate_confidence_score(response_data),
          last_risk_calculated_at: Time.current
        )
      end

      if prediction
        format_result(prediction, status: "success")
      else
        {
          road_id: road.id || 0,
          disruption_probability: prob,
          probability_percentage: (prob * 100.0).round(1),
          risk_level: r_level,
          prediction_window_hours: response_data["prediction_window_hours"] || 24,
          model_version: model_ver,
          algorithm: algo,
          status: "success",
          top_factors: factors,
          narrative_explanation: narrative,
          predicted_at: Time.current
        }
      end
    end

    def record_fallback_prediction(payload, reason)
      # In fallback mode, provide an offline estimation based on physical factors
      # so the UI can gracefully inform the user
      latest = (road.is_a?(Road) && road.persisted?) ? road.disruption_predictions.recent.first : nil

      if latest && latest.predicted_at > 2.hours.ago
        return format_result(latest, status: "cached", notice: "Displaying cached ML prediction (#{reason})")
      end

      # Heuristic fallback probability approximation
      r_score = (road.respond_to?(:risk_score) ? road.risk_score : 20.0).to_f
      heuristic_prob = (r_score / 100.0 * 0.85).clamp(0.05, 0.95).round(3)
      heuristic_level = case heuristic_prob
                        when 0.0..0.25 then "low"
                        when 0.26..0.50 then "moderate"
                        when 0.51..0.75 then "high"
                        else "critical"
                        end

      {
        road_id: road.id || 0,
        disruption_probability: heuristic_prob,
        risk_level: heuristic_level,
        probability_percentage: (heuristic_prob * 100.0).round(1),
        prediction_window_hours: 24,
        model_version: "heuristic-fallback",
        algorithm: "RuleBasedFallback",
        status: "fallback",
        top_factors: [
          {
            feature: "baseline_risk",
            importance: "medium",
            label: "🤖 Hybrid Rule Score",
            value: r_score,
            description: "Calculated from environmental telemetry while ML server is offline."
          }
        ],
        narrative_explanation: "ML prediction service currently offline. Displaying heuristic baseline estimation.",
        predicted_at: Time.current
      }
    end

    def format_result(prediction, status: "success", notice: nil)
      {
        id: prediction.id,
        road_id: prediction.road_id,
        disruption_probability: prediction.disruption_probability,
        probability_percentage: prediction.probability_percentage,
        risk_level: prediction.risk_level,
        prediction_window_hours: prediction.prediction_window_hours,
        model_version: prediction.model_version,
        algorithm: prediction.algorithm,
        status: status,
        notice: notice,
        top_factors: prediction.top_factors,
        narrative_explanation: prediction.narrative_explanation,
        predicted_at: prediction.predicted_at
      }
    end

    def calculate_confidence_score(response_data)
      # Extract test metrics if available in metadata
      roc = response_data.dig("model_metadata", "metrics", "roc_auc").to_f
      roc > 0.0 ? (roc * 100.0).round(1) : 85.0
    end

    def find_recent_incidents
      if defined?(Incident) && road.respond_to?(:state)
        Incident.where(state: road.state).recent.limit(5)
      else
        []
      end
    end

    def extract_elevation
      # Base elevation heuristic from road numbers / state
      r_state = road.respond_to?(:state) ? road.state : "Assam"
      r_num = road.respond_to?(:road_number) ? road.road_number.to_s : ""
      case r_state
      when "Arunachal Pradesh", "Sikkim"
        r_num.include?("229") ? 3850.0 : 1850.0
      when "Meghalaya", "Nagaland", "Mizoram"
        1350.0
      when "Manipur"
        980.0
      else
        120.0
      end
    end

    def extract_slope
      r_state = road.respond_to?(:state) ? road.state : "Assam"
      r_num = road.respond_to?(:road_number) ? road.road_number.to_s : ""
      case r_state
      when "Arunachal Pradesh", "Sikkim"
        r_num.include?("229") ? 42.0 : 34.0
      when "Meghalaya", "Nagaland", "Mizoram"
        28.0
      when "Manipur"
        20.0
      else
        8.0
      end
    end
  end
end
