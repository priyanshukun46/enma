class CreateLocations < ActiveRecord::Migration[8.1]
  def change
    create_table :locations do |t|
      t.string :name
      t.string :location_type
      t.float :latitude
      t.float :longitude
      t.integer :population
      t.float :accessibility_score
      t.string :district
      t.string :state

      t.timestamps
    end
  end
end
