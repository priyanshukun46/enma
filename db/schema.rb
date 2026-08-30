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

ActiveRecord::Schema[8.1].define(version: 2026_08_30_170000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  create_table "users", force: :cascade do |t|
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "name", null: false
    t.string "password_digest"
    t.string "provider"
    t.string "role", default: "operator", null: false
    t.string "uid"
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid"
  end

  create_table "warehouses", force: :cascade do |t|
    t.integer "capacity"
    t.datetime "created_at", null: false
    t.float "latitude"
    t.float "longitude"
    t.string "name"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "emergencies", "locations"
  add_foreign_key "logistics_routes", "locations", column: "destination_id"
  add_foreign_key "logistics_routes", "locations", column: "origin_id"
end
