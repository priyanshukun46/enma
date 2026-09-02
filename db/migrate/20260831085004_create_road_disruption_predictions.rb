class CreateRoadDisruptionPredictions < ActiveRecord::Migration[8.1]
  def change
    create_table :road_disruption_predictions do |t|
      t.references :road, null: false, foreign_key: true, index: true
      t.float :disruption_probability, null: false, default: 0.0
      t.string :risk_level, null: false, default: "low"
      t.integer :prediction_window_hours, default: 24
      t.string :model_version, default: "1.0.0"
      t.string :algorithm, default: "MLClassifier"
      t.string :status, default: "success" # success, fallback, unavailable
      t.text :narrative_explanation
      t.text :input_snapshot_json
      t.text :top_factors_json
      t.datetime :predicted_at, null: false, default: -> { "CURRENT_TIMESTAMP" }

      t.timestamps
    end

    add_index :road_disruption_predictions, [:road_id, :predicted_at]
    add_index :road_disruption_predictions, :risk_level
  end
end
