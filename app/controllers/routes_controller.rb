class RoutesController < ApplicationController
  before_action :load_form_options

  def index
    # Handle pre-fill from Emergency Command Center or URL params or default to Guwahati -> Shillong
    if params[:emergency_id].present?
      prefill_from_emergency(params[:emergency_id])
    else
      origin_id = params[:origin_id].presence || Location.find_by(name: "Guwahati")&.id || @locations.first&.id
      destination_id = params[:destination_id].presence || Location.find_by(name: "Shillong")&.id || @locations.second&.id
      vehicle_type = params[:vehicle_type].presence || "Truck"

      if origin_id.present? && destination_id.present? && origin_id.to_s != destination_id.to_s
        process_route_calculation(origin_id, destination_id, vehicle_type)
      end
    end

    respond_to do |format|
      format.html
      format.json { render json: @results }
    end
  end

  def calculate
    origin_id = params[:origin_id]
    destination_id = params[:destination_id]
    vehicle_type = params[:vehicle_type].presence || "Truck"

    if origin_id.blank? || destination_id.blank?
      respond_to do |format|
        format.html do
          flash.now[:alert] = "Please select both an Origin and a Destination location."
          render :index, status: :unprocessable_entity
        end
        format.json { render json: { error: "Missing origin or destination" }, status: :unprocessable_entity }
      end
      return
    end

    if origin_id.to_s == destination_id.to_s
      respond_to do |format|
        format.html do
          flash.now[:alert] = "Origin and Destination cannot be the same location. Please select distinct locations."
          render :index, status: :unprocessable_entity
        end
        format.json { render json: { error: "Same location" }, status: :unprocessable_entity }
      end
      return
    end

    process_route_calculation(origin_id, destination_id, vehicle_type)

    respond_to do |format|
      format.html { render :index }
      format.json { render json: @results }
    end
  end

  private

  def load_form_options
    @locations = Location.order(:name)
    @vehicle_types = [
      "Truck",
      "Ambulance",
      "Emergency Vehicle",
      "Supply Vehicle",
      "Personal Vehicle"
    ]
    @recent_routes = LogisticsRoute.includes(:origin, :destination).recent.limit(8)
    @active_emergencies_count = Emergency.where(status: ["Active", "Responding"]).count
  end

  def prefill_from_emergency(emergency_id)
    emergency = Emergency.find_by(id: emergency_id)
    return unless emergency

    # Find the optimal warehouse as origin
    warehouse = Warehouse.first
    # Find destination location matching emergency coordinates or nearest
    dest_loc = emergency.location || Location.find_by(name: emergency.title.split.first) || Location.first

    # Pre-select warehouse as origin (match by name or use closest location)
    orig_loc = Location.find_by(name: "Guwahati") || Location.first

    @origin = orig_loc
    @destination = dest_loc
    @selected_vehicle = "Emergency Vehicle"

    process_route_calculation(@origin.id, @destination.id, @selected_vehicle)
  end

  def process_route_calculation(origin_id, destination_id, vehicle_type)
    @origin = Location.find_by(id: origin_id)
    @destination = Location.find_by(id: destination_id)
    @selected_vehicle = vehicle_type.presence || "Truck"

    unless @origin && @destination
      flash.now[:alert] = "Invalid origin or destination location selected."
      return
    end

    begin
      service = RouteOptimizationService.new(
        origin: @origin,
        destination: @destination,
        vehicle_type: @selected_vehicle
      )
      @results = service.calculate

      # Persist route analysis in database
      save_calculated_routes(@origin, @destination, @selected_vehicle, @results)
      
      # Reload recent routes
      @recent_routes = LogisticsRoute.includes(:origin, :destination).recent.limit(8)
    rescue StandardError => e
      flash.now[:alert] = "Route analysis failed: #{e.message}"
    end
  end

  def save_calculated_routes(orig, dest, vtype, results)
    return unless results && results[:routes]

    results[:routes].each do |type_key, route_data|
      LogisticsRoute.create!(
        origin: orig,
        destination: dest,
        vehicle_type: vtype,
        distance: route_data[:distance_km],
        estimated_time: route_data[:estimated_hours],
        risk_score: route_data[:risk_score],
        route_type: type_key.to_s,
        status: "analyzed",
        recommended: route_data[:is_recommended] || false,
        waypoints_json: route_data[:coordinates].to_json,
        summary: route_data[:summary]
      )
    end
  end
end
