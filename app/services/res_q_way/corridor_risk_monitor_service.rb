module ResQWay
  class CorridorRiskMonitorService
    EARTH_RADIUS_KM = 6371.0

    attr_reader :vehicle, :shipment, :current_lat, :current_lon

    def initialize(vehicle:, shipment: nil, current_lat:, current_lon:)
      @vehicle = vehicle
      @shipment = shipment
      @current_lat = current_lat.to_f
      @current_lon = current_lon.to_f
    end

    def evaluate
      # 1. Match nearest road segment
      nearest_road = find_nearest_road
      road_risk = nearest_road&.risk_score.to_f || 20.0
      ml_prob = nearest_road&.ml_disruption_probability.to_f || 0.15
      road_name = nearest_road&.name.presence || nearest_road&.road_number || "Regional Corridor"

      # 2. Check for nearby active incidents
      nearby_incident = find_nearby_incident

      # 3. Create alerts if hazardous conditions detected
      alerts_created = []

      if nearby_incident.present?
        alerts_created << create_incident_alert(nearby_incident)
      elsif road_risk >= 70.0 || ml_prob >= 0.75
        alerts_created << create_high_risk_alert(road_name, road_risk, ml_prob)
      end

      {
        road_name: road_name,
        road_risk_score: road_risk.round(1),
        ml_disruption_probability: ml_prob.round(2),
        nearby_incident: nearby_incident,
        alerts_created: alerts_created.compact
      }
    end

    private

    def find_nearest_road
      return nil unless defined?(Road)
      all_roads = Road.all.to_a
      all_roads.min_by do |r|
        coords = r.coordinates || []
        if coords.any?
          coords.map { |c| haversine(current_lat, current_lon, c[0].to_f, c[1].to_f) }.min
        else
          999.0
        end
      end
    end

    def find_nearby_incident
      return nil unless defined?(Incident)
      Incident.active_or_reported.recent.find do |inc|
        haversine(current_lat, current_lon, inc.latitude, inc.longitude) <= 15.0 # within 15 km
      end
    end

    def create_high_risk_alert(road_name, risk_score, ml_prob)
      dedup_key = "high_risk_#{vehicle.id}_#{road_name.parameterize}_#{Time.current.strftime('%Y%m%d%H')}"
      return nil if LogisticsAlert.where(dedup_key: dedup_key).exists?

      LogisticsAlert.create!(
        vehicle: vehicle,
        shipment: shipment,
        alert_type: "high_risk_corridor",
        severity: risk_score >= 80.0 ? "critical" : "high",
        title: "⚠ High-Risk Corridor Entry: #{road_name}",
        message: "Vehicle #{vehicle.registration_number} entered #{road_name}. Risk score is #{risk_score.round(0)}/100 with #{(ml_prob * 100).round(0)}% ML disruption probability.",
        location_name: road_name,
        latitude: current_lat,
        longitude: current_lon,
        recommended_action: "Monitor vehicle speed closely and prepare alternate bypass if condition degrades.",
        dedup_key: dedup_key
      )
    end

    def create_incident_alert(incident)
      dedup_key = "incident_ahead_#{vehicle.id}_#{incident.id}"
      return nil if LogisticsAlert.where(dedup_key: dedup_key).exists?

      LogisticsAlert.create!(
        vehicle: vehicle,
        shipment: shipment,
        alert_type: "incident_ahead",
        severity: "critical",
        title: "🚨 Active Hazard Ahead: #{incident.incident_type.titleize}",
        message: "Active #{incident.incident_type} reported within 15 km of #{vehicle.registration_number}. Severity: #{incident.severity.upcase}.",
        location_name: incident.location_name || "En-route Corridor",
        latitude: incident.latitude,
        longitude: incident.longitude,
        recommended_action: "Review ResQWay rerouting recommendation to avoid blocked mountain cut.",
        dedup_key: dedup_key
      )
    end

    def haversine(lat1, lon1, lat2, lon2)
      return 0.0 if lat1.nil? || lon1.nil? || lat2.nil? || lon2.nil?
      dlat = (lat2 - lat1) * Math::PI / 180.0
      dlon = (lon2 - lon1) * Math::PI / 180.0
      a = Math.sin(dlat / 2.0)**2 + Math.cos(lat1 * Math::PI / 180.0) * Math.cos(lat2 * Math::PI / 180.0) * Math.sin(dlon / 2.0)**2
      c = 2.0 * Math.atan2(Math.sqrt(a), Math.sqrt(1.0 - a))
      EARTH_RADIUS_KM * c
    end
  end
end
