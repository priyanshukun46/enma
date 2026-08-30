class MapsController < ApplicationController
  def index
    @locations = Location.all.map do |loc|
      analysis = loc.accessibility_analysis
      loc.as_json.merge(
        accessibility_category: analysis[:category],
        risk_level: analysis[:risk_level],
        primary_risk_factor: analysis[:primary_risk_factor]
      )
    end
    @warehouses = Warehouse.all
    @emergencies = Emergency.where(status: ["Active", "open"])
  end
end
