# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_02_092008) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "emergencies", force: :cascade do |t|
    t.float "affected_radius", default: 50.0
    t.datetime "created_at", null: false
    t.text "description"
    t.string "emergency_type"
    t.float "latitude"
    t.bigint "location_id"
    t.float "longitude"
    t.string "severity"
    t.datetime "simulated_at"
    t.string "status"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["location_id"], name: "index_emergencies_on_location_id"
  end

  create_table "incidents", force: :cascade do |t|
    t.text "ai_classification_json"
    t.float "ai_confidence_score"
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.string "district"
    t.string "incident_type", default: "landslide", null: false
    t.float "latitude", null: false
    t.string "location_name"
    t.float "longitude", null: false
    t.datetime "reported_at", null: false
    t.string "severity", default: "medium", null: false
    t.string "state"
    t.string "status", default: "reported", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["incident_type"], name: "index_incidents_on_incident_type"
    t.index ["reported_at"], name: "index_incidents_on_reported_at"
    t.index ["severity"], name: "index_incidents_on_severity"
    t.index ["status"], name: "index_incidents_on_status"
    t.index ["user_id"], name: "index_incidents_on_user_id"
  end

  create_table "locations", force: :cascade do |t|
    t.float "accessibility_score"
    t.datetime "created_at", null: false
    t.float "distance_to_hospital", default: 15.0
    t.float "distance_to_warehouse", default: 25.0
    t.string "district"
    t.string "landslide_risk", default: "medium"
    t.float "latitude"
    t.string "location_type"
    t.float "longitude"
    t.string "name"
    t.integer "population"
    t.string "rainfall_level", default: "moderate"
    t.string "road_quality", default: "moderate"
    t.string "state"
    t.string "transport_availability", default: "medium"
    t.datetime "updated_at", null: false
  end

  create_table "logistics_alerts", force: :cascade do |t|
    t.string "alert_type", null: false
    t.datetime "created_at", null: false
    t.string "dedup_key"
    t.float "latitude"
    t.string "location_name"
    t.float "longitude"
    t.text "message", null: false
    t.text "metadata_json"
    t.text "recommended_action"
    t.string "severity", default: "warning", null: false
    t.bigint "shipment_id"
    t.string "status", default: "active", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "vehicle_id"
    t.index ["alert_type"], name: "index_logistics_alerts_on_alert_type"
    t.index ["dedup_key"], name: "index_logistics_alerts_on_dedup_key"
    t.index ["severity"], name: "index_logistics_alerts_on_severity"
    t.index ["shipment_id"], name: "index_logistics_alerts_on_shipment_id"
    t.index ["status"], name: "index_logistics_alerts_on_status"
    t.index ["vehicle_id"], name: "index_logistics_alerts_on_vehicle_id"
  end

  create_table "logistics_routes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "destination_id", null: false
    t.float "distance"
    t.float "estimated_time"
    t.bigint "origin_id", null: false
    t.boolean "recommended", default: false
    t.float "risk_score"
    t.string "route_type"
    t.string "status", default: "analyzed"
    t.text "summary"
    t.datetime "updated_at", null: false
    t.string "vehicle_type", default: "Truck"
    t.text "waypoints_json"
    t.index ["destination_id"], name: "index_logistics_routes_on_destination_id"
    t.index ["origin_id"], name: "index_logistics_routes_on_origin_id"
  end

  create_table "response_plans", force: :cascade do |t|
    t.text "action_items"
    t.integer "affected_communities_count"
    t.datetime "created_at", null: false
    t.bigint "emergency_id", null: false
    t.string "estimated_response_time"
    t.datetime "generated_at"
    t.text "plan_payload"
    t.text "primary_risks"
    t.string "route_title"
    t.string "severity_level"
    t.float "severity_score"
    t.string "status"
    t.integer "total_population_at_risk"
    t.datetime "updated_at", null: false
    t.string "warehouse_name"
    t.index ["emergency_id"], name: "index_response_plans_on_emergency_id"
  end

  create_table "road_disruption_predictions", force: :cascade do |t|
    t.string "algorithm", default: "MLClassifier"
    t.datetime "created_at", null: false
    t.float "disruption_probability", default: 0.0, null: false
    t.text "input_snapshot_json"
    t.string "model_version", default: "1.0.0"
    t.text "narrative_explanation"
    t.datetime "predicted_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.integer "prediction_window_hours", default: 24
    t.string "risk_level", default: "low", null: false
    t.bigint "road_id", null: false
    t.string "status", default: "success"
    t.text "top_factors_json"
    t.datetime "updated_at", null: false
    t.index ["risk_level"], name: "index_road_disruption_predictions_on_risk_level"
    t.index ["road_id", "predicted_at"], name: "index_road_disruption_predictions_on_road_id_and_predicted_at"
    t.index ["road_id"], name: "index_road_disruption_predictions_on_road_id"
  end

  create_table "road_risk_assessments", force: :cascade do |t|
    t.datetime "calculated_at", null: false
    t.float "condition_risk", default: 0.0, null: false
    t.datetime "created_at", null: false
    t.text "factors_breakdown_json"
    t.float "geographic_risk", default: 0.0, null: false
    t.float "historical_risk", default: 0.0, null: false
    t.float "incident_risk", default: 0.0, null: false
    t.string "risk_level", null: false
    t.float "risk_score", null: false
    t.bigint "road_id", null: false
    t.string "trigger_source", default: "system"
    t.datetime "updated_at", null: false
    t.float "weather_risk", default: 0.0, null: false
    t.index ["calculated_at"], name: "index_road_risk_assessments_on_calculated_at"
    t.index ["road_id"], name: "index_road_risk_assessments_on_road_id"
  end

  create_table "roads", force: :cascade do |t|
    t.float "condition_risk", default: 0.0, null: false
    t.datetime "created_at", null: false
    t.string "district"
    t.float "geographic_risk", default: 0.0, null: false
    t.text "geometry_coordinates"
    t.float "historical_risk", default: 0.0, null: false
    t.float "incident_risk", default: 0.0, null: false
    t.datetime "last_risk_calculated_at"
    t.datetime "last_updated_at"
    t.float "length_km"
    t.float "ml_confidence_score"
    t.float "ml_disruption_probability"
    t.string "name", null: false
    t.text "reason"
    t.string "risk_level", default: "low", null: false
    t.float "risk_score", default: 0.0, null: false
    t.string "road_condition", default: "good", null: false
    t.string "road_number", null: false
    t.string "state", null: false
    t.string "status", default: "accessible", null: false
    t.datetime "updated_at", null: false
    t.float "weather_risk", default: 0.0, null: false
    t.index ["risk_level"], name: "index_roads_on_risk_level"
    t.index ["risk_score"], name: "index_roads_on_risk_score"
    t.index ["road_number"], name: "index_roads_on_road_number"
    t.index ["state"], name: "index_roads_on_state"
    t.index ["status"], name: "index_roads_on_status"
  end

  create_table "route_analyses", force: :cascade do |t|
    t.text "all_routes_payload_json"
    t.datetime "analyzed_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "cargo_type", default: "General Supplies"
    t.float "confidence_score"
    t.datetime "created_at", null: false
    t.bigint "destination_id"
    t.string "destination_name"
    t.float "distance_km"
    t.integer "enma_adjusted_eta_minutes"
    t.text "explainable_reasons_json"
    t.float "ml_disruption_probability"
    t.float "optimization_score"
    t.bigint "origin_id"
    t.string "origin_name"
    t.string "priority_mode", default: "balanced", null: false
    t.integer "provider_eta_minutes"
    t.string "recommended_route_name"
    t.string "recommended_route_type"
    t.float "route_risk_score"
    t.text "segment_analysis_json"
    t.string "status", default: "active"
    t.text "tradeoff_summary"
    t.datetime "updated_at", null: false
    t.string "vehicle_type", default: "Truck", null: false
    t.index ["destination_id"], name: "index_route_analyses_on_destination_id"
    t.index ["origin_id", "destination_id"], name: "index_route_analyses_on_origin_id_and_destination_id"
    t.index ["origin_id"], name: "index_route_analyses_on_origin_id"
    t.index ["priority_mode"], name: "index_route_analyses_on_priority_mode"
    t.index ["status"], name: "index_route_analyses_on_status"
  end

  create_table "shipments", force: :cascade do |t|
    t.text "active_rerouting_recommendation_json"
    t.datetime "actual_departure"
    t.string "cargo_type", default: "medicine", null: false
    t.datetime "created_at", null: false
    t.float "current_corridor_risk", default: 0.0
    t.datetime "current_estimated_eta"
    t.integer "delay_minutes", default: 0
    t.bigint "destination_id"
    t.float "destination_latitude"
    t.float "destination_longitude"
    t.string "destination_name"
    t.boolean "deviation_detected", default: false
    t.float "deviation_distance_meters", default: 0.0
    t.float "distance_traveled_km", default: 0.0
    t.datetime "enma_adjusted_eta"
    t.datetime "estimated_departure"
    t.boolean "is_simulated", default: false
    t.float "ml_disruption_probability", default: 0.0
    t.bigint "origin_id"
    t.float "origin_latitude"
    t.float "origin_longitude"
    t.string "origin_name"
    t.text "planned_route_geometry_json"
    t.string "priority", default: "normal", null: false
    t.float "progress_percentage", default: 0.0
    t.datetime "provider_planned_eta"
    t.bigint "route_analysis_id"
    t.string "status", default: "planned", null: false
    t.float "total_distance_km", default: 0.0
    t.string "tracking_number", null: false
    t.datetime "updated_at", null: false
    t.bigint "vehicle_id"
    t.index ["cargo_type"], name: "index_shipments_on_cargo_type"
    t.index ["destination_id"], name: "index_shipments_on_destination_id"
    t.index ["origin_id"], name: "index_shipments_on_origin_id"
    t.index ["priority"], name: "index_shipments_on_priority"
    t.index ["route_analysis_id"], name: "index_shipments_on_route_analysis_id"
    t.index ["status"], name: "index_shipments_on_status"
    t.index ["tracking_number"], name: "index_shipments_on_tracking_number", unique: true
    t.index ["vehicle_id"], name: "index_shipments_on_vehicle_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "email_address", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name", null: false
    t.string "password_digest"
    t.string "provider"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "role", default: "operator", null: false
    t.string "uid"
    t.datetime "updated_at", null: false
    t.string "username"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "vehicle_locations", force: :cascade do |t|
    t.float "accuracy"
    t.datetime "created_at", null: false
    t.float "heading"
    t.float "latitude", null: false
    t.float "longitude", null: false
    t.text "raw_payload_json"
    t.datetime "recorded_at", null: false
    t.bigint "shipment_id"
    t.string "source", default: "mobile", null: false
    t.float "speed"
    t.datetime "updated_at", null: false
    t.bigint "vehicle_id", null: false
    t.index ["recorded_at"], name: "index_vehicle_locations_on_recorded_at"
    t.index ["shipment_id"], name: "index_vehicle_locations_on_shipment_id"
    t.index ["vehicle_id", "recorded_at"], name: "index_vehicle_locations_on_vehicle_id_and_recorded_at"
    t.index ["vehicle_id"], name: "index_vehicle_locations_on_vehicle_id"
  end

  create_table "vehicles", force: :cascade do |t|
    t.string "api_auth_token"
    t.float "capacity", default: 5000.0
    t.datetime "created_at", null: false
    t.float "current_heading", default: 0.0
    t.float "current_latitude"
    t.float "current_longitude"
    t.float "current_speed", default: 0.0
    t.string "driver_name"
    t.string "driver_phone"
    t.datetime "last_location_at"
    t.text "metadata_json"
    t.string "registration_number", null: false
    t.string "status", default: "available", null: false
    t.datetime "updated_at", null: false
    t.string "vehicle_type", default: "Truck", null: false
    t.index ["api_auth_token"], name: "index_vehicles_on_api_auth_token", unique: true
    t.index ["registration_number"], name: "index_vehicles_on_registration_number", unique: true
    t.index ["status"], name: "index_vehicles_on_status"
    t.index ["vehicle_type"], name: "index_vehicles_on_vehicle_type"
  end

  create_table "warehouses", force: :cascade do |t|
    t.string "address"
    t.integer "capacity"
    t.string "contact_phone"
    t.datetime "created_at", null: false
    t.string "district"
    t.float "latitude"
    t.bigint "location_id"
    t.float "longitude"
    t.string "name"
    t.string "operational_status", default: "OPERATIONAL"
    t.float "readiness_score", default: 85.0
    t.text "resources_json"
    t.string "state"
    t.datetime "updated_at", null: false
    t.integer "utilized_capacity", default: 0
    t.index ["location_id"], name: "index_warehouses_on_location_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "emergencies", "locations"
  add_foreign_key "incidents", "users"
  add_foreign_key "logistics_alerts", "shipments"
  add_foreign_key "logistics_alerts", "vehicles"
  add_foreign_key "logistics_routes", "locations", column: "destination_id"
  add_foreign_key "logistics_routes", "locations", column: "origin_id"
  add_foreign_key "response_plans", "emergencies"
  add_foreign_key "road_disruption_predictions", "roads"
  add_foreign_key "road_risk_assessments", "roads"
  add_foreign_key "route_analyses", "locations", column: "destination_id"
  add_foreign_key "route_analyses", "locations", column: "origin_id"
  add_foreign_key "shipments", "locations", column: "destination_id"
  add_foreign_key "shipments", "locations", column: "origin_id"
  add_foreign_key "shipments", "route_analyses"
  add_foreign_key "shipments", "vehicles"
  add_foreign_key "vehicle_locations", "shipments"
  add_foreign_key "vehicle_locations", "vehicles"
  add_foreign_key "warehouses", "locations", on_delete: :nullify
end
