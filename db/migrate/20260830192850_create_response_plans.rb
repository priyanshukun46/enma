class CreateResponsePlans < ActiveRecord::Migration[8.1]
  def change
    create_table :response_plans do |t|
      t.references :emergency, null: false, foreign_key: true
      t.string :warehouse_name
      t.string :route_title
      t.string :estimated_response_time
      t.integer :total_population_at_risk
      t.integer :affected_communities_count
      t.float :severity_score
      t.string :severity_level
      t.text :primary_risks
      t.text :action_items
      t.text :plan_payload
      t.string :status
      t.datetime :generated_at

      t.timestamps
    end
  end
end
