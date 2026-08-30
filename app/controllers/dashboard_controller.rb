class DashboardController < ApplicationController
  def index
    @total_locations = Location.count
    @critical_accessibility_zones = Location.critical_accessibility.count
    @active_emergencies = Emergency.where(status: "Active").count
    @total_warehouses = Warehouse.count
    @critical_locations = Location.order(accessibility_score: :asc).limit(5)
  end
end
