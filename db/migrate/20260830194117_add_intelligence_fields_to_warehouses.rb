class AddIntelligenceFieldsToWarehouses < ActiveRecord::Migration[8.1]
  def change
    add_column :warehouses, :location_id, :bigint
    add_column :warehouses, :district, :string
    add_column :warehouses, :state, :string
    add_column :warehouses, :utilized_capacity, :integer, default: 0
    add_column :warehouses, :operational_status, :string, default: "OPERATIONAL"
    add_column :warehouses, :readiness_score, :float, default: 85.0
    add_column :warehouses, :resources_json, :text
    add_column :warehouses, :contact_phone, :string
    add_column :warehouses, :address, :string
    add_index :warehouses, :location_id
    add_foreign_key :warehouses, :locations, on_delete: :nullify
  end
end
