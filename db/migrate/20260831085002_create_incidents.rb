class CreateIncidents < ActiveRecord::Migration[8.1]
  def change
    create_table :incidents do |t|
      t.string :incident_type, null: false, default: "landslide"
      t.string :severity, null: false, default: "medium"
      t.string :status, null: false, default: "reported"
      t.text :description, null: false
      t.float :latitude, null: false
      t.float :longitude, null: false
      t.string :location_name
      t.string :district
      t.string :state
      t.datetime :reported_at, null: false
      t.references :user, foreign_key: true
      t.text :ai_classification_json
      t.float :ai_confidence_score

      t.timestamps
    end

    add_index :incidents, :incident_type
    add_index :incidents, :severity
    add_index :incidents, :status
    add_index :incidents, :reported_at
  end
end
