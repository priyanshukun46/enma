module Enma
  class IncidentReroutingService
    attr_reader :shipment, :incident

    def initialize(shipment:, incident: nil)
      @shipment = shipment
      @incident = incident
    end

    def generate_recommendation
      orig = shipment.origin || Location.find_by(name: shipment.origin_name) || Location.first
      dest = shipment.destination || Location.find_by(name: shipment.destination_name) || Location.second

      return nil unless orig && dest

      # Run recommendation in Safest / Emergency mode
      result = Enma::RouteRecommendationService.new(
        origin: orig,
        destination: dest,
        priority_mode: "safest",
        vehicle_type: shipment.vehicle&.vehicle_type || "Truck",
        cargo_type: shipment.cargo_type.titleize
      ).recommend

      champion = result[:recommended_route]
      return nil unless champion

      curr_dist = shipment.total_distance_km.to_f
      alt_dist = champion[:distance_km].to_f
      dist_diff = (alt_dist - curr_dist).round(1)

      curr_risk = shipment.current_corridor_risk.to_f
      alt_risk = champion[:route_risk_score].to_f
      risk_reduction_pct = curr_risk > 0 ? (((curr_risk - alt_risk) / curr_risk) * 100.0).clamp(10.0, 90.0).round : 45

      recommendation = {
        generated_at: Time.current,
        incident_id: incident&.id,
        incident_type: incident&.incident_type || "landslide",
        incident_severity: incident&.severity || "critical",
        recommended_route_id: champion[:id],
        recommended_route_name: champion[:title],
        additional_distance_km: [dist_diff, 0.0].max,
        additional_time_minutes: [champion[:delay_minutes] || 25, 10].max,
        risk_reduction_percentage: risk_reduction_pct,
        new_risk_score: alt_risk,
        coordinates: champion[:coordinates],
        tradeoff_summary: "Critical hazard detected ahead. Switching to #{champion[:title]} provides #{risk_reduction_pct}% lower risk with +#{dist_diff} km detour."
      }

      shipment.update_columns(
        active_rerouting_recommendation_json: recommendation,
        status: "rerouting"
      )

      # Create high-priority Logistics Alert
      dedup_key = "reroute_rec_#{shipment.id}_#{incident&.id || 'hazard'}"
      unless LogisticsAlert.where(dedup_key: dedup_key).exists?
        LogisticsAlert.create!(
          vehicle: shipment.vehicle,
          shipment: shipment,
          alert_type: "blocked_route",
          severity: "critical",
          title: "🚨 Rerouting Recommended: #{champion[:title]}",
          message: recommendation[:tradeoff_summary],
          location_name: incident&.location_name || shipment.destination_name,
          latitude: incident&.latitude || shipment.destination_latitude,
          longitude: incident&.longitude || shipment.destination_longitude,
          recommended_action: "Confirm dispatcher approval to deploy bypass route #{champion[:title]}.",
          dedup_key: dedup_key
        )
      end

      recommendation
    end
  end
end
