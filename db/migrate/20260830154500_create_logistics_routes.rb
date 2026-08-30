class CreateLogisticsRoutes < ActiveRecord::Migration[8.1]
  def change
    create_table :logistics_routes do |t|
      t.references :origin, null: false, foreign_key: { to_table: :locations }
      t.references :destination, null: false, foreign_key: { to_table: :locations }
      t.string :vehicle_type, default: "Truck"
      t.float :distance
      t.float :estimated_time
      t.float :risk_score
      t.string :route_type
      t.string :status, default: "analyzed"
      t.boolean :recommended, default: false
      t.text :waypoints_json
      t.text :summary

      t.timestamps
    end
  end
end
