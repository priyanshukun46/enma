class PagesController < ApplicationController
  def landing
    @total_locations = Location.count
    @total_warehouses = Warehouse.count
    @total_emergencies = Emergency.count
    @critical_zones = Location.critical_accessibility.count
  end

  def demo
    @step = [params[:step].to_i, 1].max
    @step = 7 if @step > 7

    # Load context data for live demo experience
    @tawang = Location.find_by(name: "Tawang") || Location.first
    @warehouse = Warehouse.find_by(name: "North East Regional Logistics Hub (Guwahati)") || Warehouse.first
    @emergency = Emergency.find_by(emergency_type: "Landslide") || Emergency.first
  end

  def architecture
  end

  def overview
    @total_locations = Location.count
    @critical_zones = Location.critical_accessibility.count
    @active_emergencies = Emergency.where(status: ["Active", "Responding"]).count
  end

  def about
  end
end
