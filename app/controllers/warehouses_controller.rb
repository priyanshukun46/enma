class WarehousesController < ApplicationController
  def index
    @warehouses = Warehouse.order(:name)

    @total_warehouses = @warehouses.count
    @operational_count = @warehouses.select { |w| w.dynamic_status == "OPERATIONAL" }.count
    @total_capacity = @warehouses.sum(&:capacity)
    @total_available_resources = @warehouses.sum(&:total_available_resources)
    @average_readiness = @warehouses.any? ? (@warehouses.sum { |w| w.readiness_score || 0 } / @warehouses.size.to_f).round(1) : 0.0
    @average_utilization = @warehouses.any? ? (@warehouses.sum(&:utilization_percentage) / @warehouses.size.to_f).round(1) : 0.0
  end

  def show
    @warehouse = Warehouse.find(params[:id])
    @recent_emergencies = Emergency.active_or_responding.recent.limit(5)
  end
end
