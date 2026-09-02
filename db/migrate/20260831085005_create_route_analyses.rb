class CreateRouteAnalyses < ActiveRecord::Migration[8.1]
  def change
    create_table :route_analyses do |t|
      t.references :origin, null: true, foreign_key: { to_table: :locations }, index: true
      t.string :origin_name
      t.references :destination, null: true, foreign_key: { to_table: :locations }, index: true
      t.string :destination_name
      t.string :priority_mode, default: "balanced", null: false
      t.string :vehicle_type, default: "Truck", null: false
      t.string :cargo_type, default: "General Supplies"
      t.string :recommended_route_type
      t.string :recommended_route_name
      t.float :distance_km
      t.integer :provider_eta_minutes
      t.integer :enma_adjusted_eta_minutes
      t.float :route_risk_score
      t.float :ml_disruption_probability
      t.float :optimization_score
      t.float :confidence_score
      t.string :status, default: "active"
      t.text :all_routes_payload_json
      t.text :segment_analysis_json
      t.text :explainable_reasons_json
      t.text :tradeoff_summary
      t.datetime :analyzed_at, null: false, default: -> { "CURRENT_TIMESTAMP" }

      t.timestamps
    end

    add_index :route_analyses, [:origin_id, :destination_id]
    add_index :route_analyses, :priority_mode
    add_index :route_analyses, :status
  end
end
