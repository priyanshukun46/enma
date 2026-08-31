module Enma
  class RoadRiskIntelligenceService
    EARTH_RADIUS_KM = 6371.0
    PROXIMITY_THRESHOLD_KM = 45.0

    attr_reader :road, :ml_provider

    def initialize(road, ml_provider: nil)
      @road = road
      @ml_provider = ml_provider || Enma::MlPredictionProvider.new
    end

    def calculate
      weather_score = calculate_weather_risk
      historical_score = calculate_historical_risk
      incident_score = calculate_incident_risk
      condition_score = calculate_condition_risk
      geographic_score = calculate_geographic_risk

      weights = Road::ENMA_RISK_WEIGHTS

      weighted_score = (
        (weather_score * weights[:weather]) +
        (historical_score * weights[:historical]) +
        (incident_score * weights[:incidents]) +
        (condition_score * weights[:condition]) +
        (geographic_score * weights[:geographic])
      ).round(1)

      final_risk_score = weighted_score.clamp(0.0, 100.0)
      calculated_level = classify_risk(final_risk_score)

      # Determine synchronized road accessibility status
      calculated_status = determine_status(final_risk_score, incident_score)

      # Optional future ML integration
      ml_result = ml_provider.predict({
        road_id: road.id,
        road_number: road.road_number,
        state: road.state,
        calculated_score: final_risk_score
      })

      {
        road_id: road.id,
        risk_score: final_risk_score,
        risk_level: calculated_level,
        status: calculated_status,
        factors: {
          weather: weather_score.round(1),
          historical: historical_score.round(1),
          incidents: incident_score.round(1),
          condition: condition_score.round(1),
          geographic: geographic_score.round(1)
        },
        weights: weights,
        ml_prediction: ml_result
      }
    end

    def calculate_and_update!(trigger_source: "system")
      result = calculate
      factors = result[:factors]
      ml_pred = result[:ml_prediction] || {}

      Road.transaction do
        road.update!(
          risk_score: result[:risk_score],
          risk_level: result[:risk_level],
          status: result[:status],
          weather_risk: factors[:weather],
          historical_risk: factors[:historical],
          incident_risk: factors[:incidents],
          condition_risk: factors[:condition],
          geographic_risk: factors[:geographic],
          last_risk_calculated_at: Time.current,
          ml_disruption_probability: ml_pred[:disruption_probability],
          ml_confidence_score: ml_pred[:confidence_score]
        )

        road.risk_assessments.create!(
          risk_score: result[:risk_score],
          risk_level: result[:risk_level],
          weather_risk: factors[:weather],
          historical_risk: factors[:historical],
          incident_risk: factors[:incidents],
          condition_risk: factors[:condition],
          geographic_risk: factors[:geographic],
          trigger_source: trigger_source,
          calculated_at: Time.current,
          factors_breakdown_json: factors
        )
      end

      result
    end

    # =========================================================================
    # Individual Risk Factor Calculations
    # =========================================================================
    def calculate_weather_risk
      # 1. Base weather risk from road attributes
      base = road.weather_risk.to_f

      # 2. Factor in active regional weather emergencies & field weather reports
      regional_weather_reports = Incident.where(state: road.state, incident_type: ["weather_disruption", "flood"])
                                         .where("reported_at >= ?", 48.hours.ago)

      if regional_weather_reports.any?
        max_severity = regional_weather_reports.maximum(:severity)
        case max_severity
        when "critical" then [base + 45.0, 95.0].min
        when "high"     then [base + 30.0, 85.0].min
        when "medium"   then [base + 15.0, 70.0].min
        else [base, 50.0].max
        end
      elsif base > 0.0
        base
      else
        # Default baseline by state terrain vulnerability
        case road.state
        when "Meghalaya", "Sikkim", "Arunachal Pradesh" then 35.0
        when "Assam", "Nagaland", "Manipur" then 25.0
        else 15.0
        end
      end
    end

    def calculate_historical_risk
      base = road.historical_risk.to_f
      return base if base > 0.0

      # Default estimation from road characteristics
      case road.road_number
      when "NH-10", "NH-13", "NH-2" then 75.0 # High historical landslide mountain lifeline
      when "NH-27S", "NH-102", "NH-306" then 60.0 # Hill corridor
      when "NH-27", "NH-37", "NH-8" then 30.0 # Multi-lane national artery
      else 40.0
      end
    end

    def calculate_incident_risk
      # Find all active/verified field incidents and emergencies in proximity to this road
      nearby_incidents = find_nearby_incidents

      if nearby_incidents.any?
        # Calculate cumulative incident risk with severity and type weighting
        max_score = 0.0
        nearby_incidents.each do |inc|
          type_multiplier = case inc.incident_type
                            when "landslide", "bridge_damage" then 1.2
                            when "flood", "road_damage" then 1.0
                            when "traffic_blockage", "accident" then 0.8
                            else 0.6
                            end

          severity_base = case inc.severity.to_s.downcase
                          when "critical" then 95.0
                          when "high"     then 75.0
                          when "medium"   then 45.0
                          when "low"      then 20.0
                          else 30.0
                          end

          score = severity_base * type_multiplier
          max_score = score if score > max_score
        end

        max_score.clamp(0.0, 100.0)
      else
        road.incident_risk.to_f
      end
    end

    def calculate_condition_risk
      cond = road.road_condition.to_s.downcase
      Road::CONDITION_SCORES[cond] || 25.0
    end

    def calculate_geographic_risk
      base = road.geographic_risk.to_f
      return base if base > 0.0

      # Estimated terrain slope risk by state and road number
      case road.state
      when "Arunachal Pradesh", "Sikkim" then 80.0
      when "Nagaland", "Meghalaya", "Mizoram", "Manipur" then 65.0
      when "Assam", "Tripura" then 25.0
      else 40.0
      end
    end

    # =========================================================================
    # Helpers & Proximity Matchers
    # =========================================================================
    def classify_risk(score)
      if score <= 25.0
        "low"
      elsif score <= 50.0
        "moderate"
      elsif score <= 75.0
        "high"
      else
        "critical"
      end
    end

    def determine_status(score, incident_score)
      if score >= 75.0 || incident_score >= 90.0
        "blocked"
      elsif score >= 50.0
        "high_risk"
      elsif score >= 25.0
        "moderate_risk"
      else
        "accessible"
      end
    end

    def find_nearby_incidents
      coords = road.coordinates
      return [] if coords.empty?

      # Find incidents within proximity threshold to any point on the road
      Incident.where("reported_at >= ?", 72.hours.ago).select do |inc|
        next false unless inc.latitude && inc.longitude

        coords.any? do |point|
          lat, lon = point[0], point[1]
          haversine(lat, lon, inc.latitude, inc.longitude) <= PROXIMITY_THRESHOLD_KM
        end
      end
    end

    def haversine(lat1, lon1, lat2, lon2)
      return 9999.0 if lat1.nil? || lon1.nil? || lat2.nil? || lon2.nil?

      dlat = (lat2 - lat1) * Math::PI / 180.0
      dlon = (lon2 - lon1) * Math::PI / 180.0
      a = Math.sin(dlat / 2.0)**2 + Math.cos(lat1 * Math::PI / 180.0) * Math.cos(lat2 * Math::PI / 180.0) * Math.sin(dlon / 2.0)**2
      EARTH_RADIUS_KM * 2.0 * Math.atan2(Math.sqrt(a), Math.sqrt(1.0 - a))
    end
  end
end
