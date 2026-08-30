class RoutesController < ApplicationController
  before_action :load_form_options

  def index
    if params[:origin_id].present? && params[:destination_id].present?
      process_route_calculation(params[:origin_id], params[:destination_id], params[:vehicle_type])
    end
  end

  def calculate
    origin_id = params[:origin_id]
    destination_id = params[:destination_id]
    vehicle_type = params[:vehicle_type]

    if origin_id.blank? || destination_id.blank?
      flash.now[:alert] = "Please select both an Origin and a Destination location."
      render :index, status: :unprocessable_entity
      return
    end

    if origin_id.to_s == destination_id.to_s
      flash.now[:alert] = "Origin and Destination cannot be the same location. Please select distinct locations."
      render :index, status: :unprocessable_entity
      return
    end

    process_route_calculation(origin_id, destination_id, vehicle_type)
    render :index
  end

  private

  def load_form_options
    @locations = Location.order(:name)
    @vehicle_types = [
      "Truck",
      "Ambulance",
      "Emergency Vehicle",
      "Supply Vehicle"
    ]
    @recent_routes = LogisticsRoute.includes(:origin, :destination).recent
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
      @recent_routes = LogisticsRoute.includes(:origin, :destination).recent
    rescue StandardError => e
      flash.now[:alert] = "Route analysis failed: #{e.message}"
    end
  end

  def save_calculated_routes(orig, dest, vtype, results)
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
        waypoints_json: route_data[:waypoints].to_json,
        summary: route_data[:description]
      )
    end
  end
end
