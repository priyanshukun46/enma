require "test_helper"

class WarehouseTest < ActiveSupport::TestCase
  setup do
    @location = Location.find_or_create_by!(name: "WH Model Test Location") do |l|
      l.state = "Assam"
      l.district = "Kamrup"
      l.latitude = 26.14
      l.longitude = 91.74
      l.population = 100000
      l.accessibility_score = 80.0
      l.road_quality = "good"
      l.rainfall_level = "low"
      l.landslide_risk = "low"
    end

    @warehouse = Warehouse.find_or_create_by!(name: "Model Test Warehouse") do |w|
      w.latitude = 26.15
      w.longitude = 91.75
      w.capacity = 10000
      w.utilized_capacity = 3000
      w.operational_status = "OPERATIONAL"
      w.readiness_score = 85.0
      w.location = @location
      w.resources_json = {
        "medical_kits" => 500, "food_packages" => 1000,
        "water_units" => 3000, "emergency_shelters" => 100,
        "fuel_liters" => 2000, "rescue_equipment" => 40
      }.to_json
    end
  end

  test "available_capacity returns correct value" do
    assert_equal 7000, @warehouse.available_capacity
  end

  test "utilization_percentage calculates correctly" do
    assert_in_delta 30.0, @warehouse.utilization_percentage, 0.1
  end

  test "utilization_percentage handles zero capacity" do
    @warehouse.capacity = 0
    assert_equal 0.0, @warehouse.utilization_percentage
  end

  test "dynamic_status returns OPERATIONAL under 60 percent" do
    @warehouse.utilized_capacity = 3000
    assert_equal "OPERATIONAL", @warehouse.dynamic_status
  end

  test "dynamic_status returns LIMITED between 60 and 85 percent" do
    @warehouse.utilized_capacity = 7000
    assert_equal "LIMITED", @warehouse.dynamic_status
  end

  test "dynamic_status returns OVERLOADED above 85 percent" do
    @warehouse.utilized_capacity = 9000
    assert_equal "OVERLOADED", @warehouse.dynamic_status
  end

  test "dynamic_status returns UNAVAILABLE when status is UNAVAILABLE" do
    @warehouse.operational_status = "UNAVAILABLE"
    assert_equal "UNAVAILABLE", @warehouse.dynamic_status
  end

  test "resources returns hash with indifferent access" do
    res = @warehouse.resources
    assert_equal 500, res[:medical_kits]
    assert_equal 500, res["medical_kits"]
  end

  test "total_available_resources sums all resource values" do
    expected = 500 + 1000 + 3000 + 100 + 2000 + 40
    assert_equal expected, @warehouse.total_available_resources
  end

  test "resource_count returns correct value for category" do
    assert_equal 500, @warehouse.resource_count(:medical_kits)
    assert_equal 1000, @warehouse.resource_count("food_packages")
  end

  test "calculate_readiness_score returns value between 0 and 100" do
    score = @warehouse.calculate_readiness_score
    assert score >= 0.0
    assert score <= 100.0
  end

  test "emergency_type_resource_match returns score for known type" do
    score = @warehouse.emergency_type_resource_match("Flood")
    assert score >= 0.0
    assert score <= 100.0
  end

  test "emergency_type_resource_match handles unknown type" do
    score = @warehouse.emergency_type_resource_match("Unknown Disaster")
    assert score >= 0.0
    assert score <= 100.0
  end

  test "status_badge_class returns correct CSS classes" do
    assert @warehouse.status_badge_class.include?("emerald")

    @warehouse.operational_status = "UNAVAILABLE"
    assert @warehouse.status_badge_class.include?("slate")
  end

  test "readiness_color_class returns emerald for high readiness" do
    @warehouse.readiness_score = 80.0
    assert @warehouse.readiness_color_class.include?("emerald")
  end

  test "readiness_color_class returns red for low readiness" do
    @warehouse.readiness_score = 30.0
    assert @warehouse.readiness_color_class.include?("red")
  end

  test "critical_resource_coverage returns percentage" do
    coverage = @warehouse.critical_resource_coverage
    assert coverage >= 0.0
    assert coverage <= 100.0
  end

  test "default resources are used when resources_json is nil" do
    @warehouse.resources_json = nil
    res = @warehouse.resources
    assert res["medical_kits"] > 0
    assert res["food_packages"] > 0
  end
end
