class VehiclesController < ApplicationController
  before_action :set_vehicle, only: [:show, :edit, :update, :destroy]

  def index
    @vehicles = Vehicle.order(:registration_number)
    @total_vehicles = @vehicles.count
    @in_transit_count = @vehicles.where(status: "in_transit").count
    @available_count = @vehicles.where(status: "available").count
    @delayed_count = @vehicles.where(status: "delayed").count
  end

  def show
    @active_shipment = @vehicle.active_shipment
    @recent_locations = @vehicle.vehicle_locations.recent.limit(20)
    @recent_alerts = @vehicle.logistics_alerts.recent.limit(10)
  end

  def new
    @vehicle = Vehicle.new
  end

  def create
    @vehicle = Vehicle.new(vehicle_params)
    if @vehicle.save
      redirect_to vehicle_path(@vehicle), notice: "Vehicle #{@vehicle.registration_number} registered successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @vehicle.update(vehicle_params)
      redirect_to vehicle_path(@vehicle), notice: "Vehicle details updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @vehicle.destroy
    redirect_to vehicles_path, notice: "Vehicle #{@vehicle.registration_number} was successfully removed."
  end

  private

  def set_vehicle
    @vehicle = Vehicle.find(params[:id])
  end

  def vehicle_params
    params.require(:vehicle).permit(
      :registration_number,
      :vehicle_type,
      :status,
      :capacity,
      :driver_name,
      :driver_phone
    )
  end
end
