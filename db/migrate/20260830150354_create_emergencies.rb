class CreateEmergencies < ActiveRecord::Migration[8.1]
  def change
    create_table :emergencies do |t|
      t.string :title
      t.string :emergency_type
      t.string :severity
      t.float :latitude
      t.float :longitude
      t.string :status

      t.timestamps
    end
  end
end
