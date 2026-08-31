class MapsController < ApplicationController
  def index
    # Load all monitored roads with dynamic filter support
    @roads_scope = Road.all

    if params[:status].present? && params[:status] != "all"
      @roads_scope = @roads_scope.by_status(params[:status])
    end

    if params[:state].present? && params[:state] != "all"
      @roads_scope = @roads_scope.by_state(params[:state])
    end

    if params[:min_risk].present? && params[:max_risk].present?
      @roads_scope = @roads_scope.by_risk_range(params[:min_risk], params[:max_risk])
    end

    @roads = @roads_scope.by_risk_desc

    # Calculate dynamic GIS intelligence metrics
    @total_roads = Road.count
    @accessible_roads = Road.accessible.count
    @moderate_risk_roads = Road.moderate_risk.count
    @high_risk_roads = Road.high_risk.count
    @blocked_roads = Road.blocked.count
    @avg_risk_score = Road.average(:risk_score)&.round(1) || 0.0

    @locations = Location.all.map do |loc|
      analysis = loc.accessibility_analysis
      loc.as_json.merge(
        accessibility_category: analysis[:category],
        risk_level: analysis[:risk_level],
        primary_risk_factor: analysis[:primary_risk_factor]
      )
    end

    @warehouses = Warehouse.all
    @emergencies = Emergency.where(status: ["Active", "Responding", "open"]).order(created_at: :desc)
    @reported_incidents = Incident.includes(:user, photos_attachments: :blob).recent
    @active_incidents_count = @emergencies.count + @reported_incidents.where(status: %w[reported verified]).count

    @states = Road::STATES
    @selected_state = params[:state].presence || "all"
    @selected_status = params[:status].presence || "all"

    # Serialized payloads for Stimulus Leaflet map
    @roads_json = @roads.map(&:as_map_json)
    @locations_json = @locations
    @warehouses_json = @warehouses.map do |w|
      {
        id: w.id,
        name: w.name,
        latitude: w.latitude,
        longitude: w.longitude,
        capacity: w.capacity,
        available_capacity: w.available_capacity,
        operational_status: w.dynamic_status,
        readiness_score: w.readiness_score,
        district: w.district,
        state: w.state
      }
    end
    @emergencies_json = @emergencies.map do |e|
      {
        id: e.id,
        title: e.title,
        emergency_type: e.emergency_type,
        severity: e.severity,
        status: e.status,
        latitude: e.latitude,
        longitude: e.longitude,
        affected_radius: e.affected_radius,
        location_name: e.location&.name,
        description: e.description,
        simulated_at: e.simulated_at&.strftime("%b %d, %H:%M")
      }
    end
    @reported_incidents_json = @reported_incidents.map { |inc| inc.as_map_json(view_context) }

    respond_to do |format|
      format.html
      format.json do
        render json: {
          roads: @roads_json,
          locations: @locations_json,
          warehouses: @warehouses_json,
          emergencies: @emergencies_json,
          incidents: @reported_incidents_json,
          metrics: {
            total_roads: @total_roads,
            accessible: @accessible_roads,
            moderate_risk: @moderate_risk_roads,
            high_risk: @high_risk_roads,
            blocked: @blocked_roads,
            avg_risk_score: @avg_risk_score,
            active_incidents: @active_incidents_count
          }
        }
      end
    end
  end
end
