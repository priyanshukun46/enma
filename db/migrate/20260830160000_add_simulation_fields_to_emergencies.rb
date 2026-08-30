class AddSimulationFieldsToEmergencies < ActiveRecord::Migration[8.1]
  def change
    add_column :emergencies, :affected_radius, :float, default: 50.0
    add_column :emergencies, :description, :text
    add_column :emergencies, :simulated_at, :datetime
    add_reference :emergencies, :location, null: true, foreign_key: true
  end
end
