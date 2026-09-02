class ShipmentsController < ApplicationController
  before_action :set_shipment, only: [:show, :simulate, :confirm_reroute]

  def index
    @shipments = Shipment.includes(:vehicle, :origin, :destination).recent
    @total_shipments = @shipments.count
    @active_count = @shipments.where(status: %w[in_transit assigned delayed rerouting]).count
    @on_time_count = @shipments.where(status: "in_transit").where("delay_minutes <= 0").count
    @delayed_count = @shipments.where(status: "delayed").or(@shipments.where("delay_minutes > 0")).count
    @high_risk_count = @shipments.where("current_corridor_risk >= 60.0 OR ml_disruption_probability >= 0.60").count
    @critical_alerts_count = LogisticsAlert.where(status: "active", severity: %w[critical high]).count

    # Active deliveries for GIS Map visualization
    @map_shipments = @shipments.where(status: %w[in_transit delayed rerouting assigned]).limit(25)
    @active_vehicles = Vehicle.where.not(current_latitude: nil, current_longitude: nil).active.limit(50)
  end

  def show
    @vehicle = @shipment.vehicle
    @recent_locations = @shipment.vehicle_locations.recent.limit(30)
    @recent_alerts = @shipment.logistics_alerts.recent.limit(10)
    @reroute_rec = @shipment.rerouting_recommendation
  end

  def new
    @shipment = Shipment.new
    @locations = Location.order(:name)
    @vehicles = Vehicle.available
  end

  def create
    @shipment = Shipment.new(shipment_params)

    # Set origin & destination coordinates
    orig = Location.find_by(id: params[:shipment][:origin_id])
    dest = Location.find_by(id: params[:shipment][:destination_id])

    if orig && dest
      @shipment.origin = orig
      @shipment.origin_name = orig.name
      @shipment.origin_latitude = orig.latitude
      @shipment.origin_longitude = orig.longitude
      @shipment.destination = dest
      @shipment.destination_name = dest.name
      @shipment.destination_latitude = dest.latitude
      @shipment.destination_longitude = dest.longitude

      # Compute planned route geometry using Enma::RouteRecommendationService
      rec_res = Enma::RouteRecommendationService.new(
        origin: orig,
        destination: dest,
        priority_mode: (@shipment.priority == "emergency" ? "emergency" : "balanced"),
        vehicle_type: @shipment.vehicle&.vehicle_type || "Truck",
        cargo_type: @shipment.cargo_type.titleize
      ).recommend

      champion = rec_res[:recommended_route]
      if champion
        @shipment.planned_route_geometry_json = champion[:coordinates]
        @shipment.total_distance_km = champion[:distance_km]
        @shipment.provider_planned_eta = Time.current + (champion[:provider_duration_minutes] || 120).minutes
        @shipment.enma_adjusted_eta = Time.current + (champion[:enma_adjusted_eta_minutes] || 150).minutes
      end
    end

    if @shipment.save
      @shipment.vehicle&.update_column(:status, "assigned")
      redirect_to shipment_path(@shipment), notice: "Shipment #{@shipment.tracking_number} dispatched successfully."
    else
      @locations = Location.order(:name)
      @vehicles = Vehicle.available
      render :new, status: :unprocessable_entity
    end
  end

  def simulate
    scenario = params[:scenario].presence || "normal_movement"
    service = Enma::GpsSimulationService.new(shipment: @shipment, scenario: scenario)
    res = service.simulate_next_step

    respond_to do |format|
      format.html { redirect_to shipment_path(@shipment), notice: "Simulated '#{scenario.titleize}': Progress is now #{@shipment.progress_percentage}%." }
      format.json { render json: res }
    end
  end

  def confirm_reroute
    rec = @shipment.rerouting_recommendation
    if rec.present? && rec[:coordinates].present?
      @shipment.update_columns(
        planned_route_geometry_json: rec[:coordinates],
        status: "in_transit",
        active_rerouting_recommendation_json: nil
      )
      redirect_to shipment_path(@shipment), notice: "Alternative detour confirmed. Route updated to bypass hazard zone."
    else
      redirect_to shipment_path(@shipment), alert: "No active rerouting recommendation found to apply."
    end
  end

  def live_map
    @active_shipments = Shipment.includes(:vehicle, :origin, :destination).where(status: %w[in_transit delayed rerouting assigned])
    @active_vehicles = Vehicle.where.not(current_latitude: nil, current_longitude: nil).active
    @critical_alerts = LogisticsAlert.active.recent.limit(10)
    @incidents = defined?(Incident) ? Incident.active_or_reported.recent.limit(20) : []
  end

  private

  def set_shipment
    @shipment = Shipment.find(params[:id])
  end

  def shipment_params
    params.require(:shipment).permit(
      :vehicle_id,
      :cargo_type,
      :priority,
      :origin_id,
      :destination_id,
      :estimated_departure
    )
  end
end
