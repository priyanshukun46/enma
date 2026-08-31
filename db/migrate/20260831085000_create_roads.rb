class CreateRoads < ActiveRecord::Migration[8.1]
  def change
    create_table :roads do |t|
      t.string :name, null: false
      t.string :road_number, null: false
      t.string :district
      t.string :state, null: false
      t.string :status, default: "accessible", null: false
      t.float :risk_score, default: 0.0, null: false
      t.text :reason
      t.float :length_km
      t.text :geometry_coordinates # Stores JSON array of [lat, lng] coordinates
      t.datetime :last_updated_at

      t.timestamps
    end

    add_index :roads, :status
    add_index :roads, :state
    add_index :roads, :risk_score
    add_index :roads, :road_number
  end
end
