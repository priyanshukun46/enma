class CreateLogisticsTrackingSystem < ActiveRecord::Migration[8.1]
  def change
    # 1. Vehicles
    create_table :vehicles do |t|
      t.string :registration_number, null: false
      t.string :vehicle_type, default: "Truck", null: false
      t.string :status, default: "available", null: false
      t.float :capacity, default: 5000.0
      t.float :current_latitude
      t.float :current_longitude
      t.float :current_speed, default: 0.0
      t.float :current_heading, default: 0.0
      t.datetime :last_location_at
      t.string :driver_name
      t.string :driver_phone
      t.string :api_auth_token
      t.text :metadata_json

      t.timestamps
    end

    add_index :vehicles, :registration_number, unique: true
    add_index :vehicles, :status
    add_index :vehicles, :vehicle_type
    add_index :vehicles, :api_auth_token, unique: true

    # 2. Shipments (Deliveries)
    create_table :shipments do |t|
      t.string :tracking_number, null: false
      t.references :vehicle, foreign_key: true, index: true, null: true
      t.string :cargo_type, default: "medicine", null: false
      t.string :priority, default: "normal", null: false
      t.references :origin, foreign_key: { to_table: :locations }, index: true, null: true
      t.string :origin_name
      t.float :origin_latitude
      t.float :origin_longitude
      t.references :destination, foreign_key: { to_table: :locations }, index: true, null: true
      t.string :destination_name
      t.float :destination_latitude
      t.float :destination_longitude
      t.string :status, default: "planned", null: false
      t.references :route_analysis, foreign_key: true, index: true, null: true
      t.text :planned_route_geometry_json
      t.float :progress_percentage, default: 0.0
      t.float :distance_traveled_km, default: 0.0
      t.float :total_distance_km, default: 0.0
      t.datetime :estimated_departure
      t.datetime :actual_departure
      t.datetime :provider_planned_eta
      t.datetime :current_estimated_eta
      t.datetime :enma_adjusted_eta
      t.integer :delay_minutes, default: 0
      t.float :current_corridor_risk, default: 0.0
      t.float :ml_disruption_probability, default: 0.0
      t.boolean :deviation_detected, default: false
      t.float :deviation_distance_meters, default: 0.0
      t.text :active_rerouting_recommendation_json
      t.boolean :is_simulated, default: false

      t.timestamps
    end

    add_index :shipments, :tracking_number, unique: true
    add_index :shipments, :status
    add_index :shipments, :cargo_type
    add_index :shipments, :priority

    # 3. Vehicle Locations (GPS Breadcrumb History)
    create_table :vehicle_locations do |t|
      t.references :vehicle, null: false, foreign_key: true, index: true
      t.references :shipment, null: true, foreign_key: true, index: true
      t.float :latitude, null: false
      t.float :longitude, null: false
      t.float :accuracy
      t.float :speed
      t.float :heading
      t.datetime :recorded_at, null: false
      t.string :source, default: "mobile", null: false
      t.text :raw_payload_json

      t.timestamps
    end

    add_index :vehicle_locations, [:vehicle_id, :recorded_at]
    add_index :vehicle_locations, :recorded_at

    # 4. Logistics Alerts
    create_table :logistics_alerts do |t|
      t.references :vehicle, foreign_key: true, index: true, null: true
      t.references :shipment, foreign_key: true, index: true, null: true
      t.string :alert_type, null: false # route_deviation, delivery_delay, high_risk_corridor, blocked_route, incident_ahead, severe_weather, vehicle_offline
      t.string :severity, default: "warning", null: false # info, warning, high, critical
      t.string :title, null: false
      t.text :message, null: false
      t.string :location_name
      t.float :latitude
      t.float :longitude
      t.text :recommended_action
      t.string :status, default: "active", null: false # active, acknowledged, resolved
      t.string :dedup_key
      t.text :metadata_json

      t.timestamps
    end

    add_index :logistics_alerts, :status
    add_index :logistics_alerts, :alert_type
    add_index :logistics_alerts, :severity
    add_index :logistics_alerts, :dedup_key
  end
end
