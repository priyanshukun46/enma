class AddIntelligenceFieldsToRoadsAndCreateAssessments < ActiveRecord::Migration[8.1]
  def change
    add_column :roads, :risk_level, :string, default: "low", null: false
    add_column :roads, :weather_risk, :float, default: 0.0, null: false
    add_column :roads, :historical_risk, :float, default: 0.0, null: false
    add_column :roads, :incident_risk, :float, default: 0.0, null: false
    add_column :roads, :condition_risk, :float, default: 0.0, null: false
    add_column :roads, :geographic_risk, :float, default: 0.0, null: false
    add_column :roads, :road_condition, :string, default: "good", null: false
    add_column :roads, :last_risk_calculated_at, :datetime
    add_column :roads, :ml_disruption_probability, :float
    add_column :roads, :ml_confidence_score, :float

    add_index :roads, :risk_level

    create_table :road_risk_assessments do |t|
      t.references :road, null: false, foreign_key: true
      t.float :risk_score, null: false
      t.string :risk_level, null: false
      t.float :weather_risk, default: 0.0, null: false
      t.float :historical_risk, default: 0.0, null: false
      t.float :incident_risk, default: 0.0, null: false
      t.float :condition_risk, default: 0.0, null: false
      t.float :geographic_risk, default: 0.0, null: false
      t.string :trigger_source, default: "system"
      t.datetime :calculated_at, null: false
      t.text :factors_breakdown_json

      t.timestamps
    end

    add_index :road_risk_assessments, :calculated_at
  end
end
