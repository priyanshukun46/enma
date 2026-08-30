class DashboardController < ApplicationController
  def index
    @total_locations = Location.count
    @critical_accessibility_zones = Location.critical_accessibility.count
    @active_emergencies = Emergency.active_or_responding.count
    @total_warehouses = Warehouse.count
    @critical_locations = Location.order(accessibility_score: :asc).limit(5)
    @active_emergency_records = Emergency.active_or_responding.recent.limit(5)
  end
end
