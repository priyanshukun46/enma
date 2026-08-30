class AddAccessibilityFactorsToLocations < ActiveRecord::Migration[8.1]
  def change
    add_column :locations, :road_quality, :string, default: "moderate"
    add_column :locations, :rainfall_level, :string, default: "moderate"
    add_column :locations, :landslide_risk, :string, default: "medium"
    add_column :locations, :transport_availability, :string, default: "medium"
    add_column :locations, :distance_to_hospital, :float, default: 15.0
    add_column :locations, :distance_to_warehouse, :float, default: 25.0
  end
end
