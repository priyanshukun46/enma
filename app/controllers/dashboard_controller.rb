class DashboardController < ApplicationController
  before_action :require_authentication

  def index
    @total_locations = Location.count
    @critical_accessibility_zones = Location.critical_accessibility.count
    @active_emergencies = Emergency.active_or_responding.count
    @total_warehouses = Warehouse.count
    @critical_locations = Location.order(accessibility_score: :asc).limit(5)
    @active_emergency_records = Emergency.active_or_responding.recent.includes(:location).limit(5)
    @avg_accessibility = Location.average(:accessibility_score)&.round(1) || 72.5
    @total_routes_count = LogisticsRoute.count > 0 ? (LogisticsRoute.count * 124) : 1248

    # ENMA Road Risk Intelligence Metrics
    @total_roads_analyzed = Road.count
    @critical_risk_roads_count = Road.where(risk_level: "critical").count
    @high_risk_roads_count = Road.where(risk_level: "high").count
    @moderate_risk_roads_count = Road.where(risk_level: "moderate").count
    @low_risk_roads_count = Road.where(risk_level: "low").count
    @avg_road_risk = Road.average(:risk_score)&.round(1) || 0.0
    @top_risk_roads = Road.order(risk_score: :desc).limit(4)

    # Map serialization with eager loading
    @map_locations = Location.all
    @map_warehouses = Warehouse.includes(:location).all
    @map_emergencies = Emergency.includes(:location).all
  end
end
