module ResQWay
  class GpsSimulationService
    attr_reader :shipment, :step_index, :scenario

    def initialize(shipment:, step_index: nil, scenario: "normal_movement")
      @shipment = shipment
      @step_index = step_index.to_i
      @scenario = scenario.to_s
    end

    def simulate_next_step
      geometry = shipment.planned_geometry
      if geometry.blank? || geometry.size < 2
        geometry = generate_default_route_geometry
        shipment.update_column(:planned_route_geometry_json, geometry)
      end

      # Determine target coordinate index
      total_pts = geometry.size
      target_idx = (step_index > 0 && step_index < total_pts) ? step_index : next_index_from_progress(total_pts)
      pt = geometry[target_idx] || geometry.first

      lat = pt[0].to_f
      lon = pt[1].to_f
      speed = 42.0

      # Handle scenarios
      case scenario
      when "vehicle_stop"
        speed = 0.0
      when "route_deviation"
        # Deviate coordinate by ~2.5 km
        lat += 0.022
        lon += 0.018
        speed = 30.0
      when "high_risk_entry"
        speed = 25.0
      when "landslide_reroute"
        # Simulate severe landslide ahead
        ahead_pt = geometry[[target_idx + 2, total_pts - 1].min]
        create_simulated_landslide(ahead_pt[0], ahead_pt[1])
      end

      # Ingest via standard GpsIngestionService
      result = GpsIngestionService.new({
        vehicle_id: shipment.vehicle&.id,
        shipment_id: shipment.id,
        latitude: lat,
        longitude: lon,
        speed: speed,
        heading: 90.0,
        accuracy: 8.0,
        recorded_at: Time.current,
        source: "simulation"
      }).process

      shipment.update_column(:is_simulated, true)

      result.merge(
        scenario: scenario,
        simulated: true,
        current_step: target_idx + 1,
        total_steps: total_pts
      )
    end

    private

    def next_index_from_progress(total_pts)
      curr_pct = shipment.progress_percentage || 0.0
      next_pct = [curr_pct + 15.0, 100.0].min
      ((next_pct / 100.0) * (total_pts - 1)).round
    end

    def generate_default_route_geometry
      # Guwahati -> Shillong corridor geometry
      [
        [26.1445, 91.7362],
        [26.0500, 91.7600],
        [25.9600, 91.7900],
        [25.8800, 91.8200],
        [25.7900, 91.8500],
        [25.7000, 91.8700],
        [25.6300, 91.8850],
        [25.5788, 91.8933]
      ]
    end

    def create_simulated_landslide(lat, lon)
      return unless defined?(Incident)

      incident = Incident.create!(
        description: "CRITICAL SIMULATED HAZARD: Massive Landslide blocking National Highway transit corridor.",
        incident_type: "landslide",
        severity: "critical",
        status: "reported",
        latitude: lat,
        longitude: lon,
        location_name: "Highland Mountain Cut",
        reported_at: Time.current
      )

      # Trigger rerouting service
      IncidentReroutingService.new(shipment: shipment, incident: incident).generate_recommendation
    end
  end
end
