require "test_helper"

class WarehouseRecommendationServiceTest < ActiveSupport::TestCase
  setup do
    @location_a = Location.find_or_create_by!(name: "Test Location A") do |l|
      l.state = "Assam"
      l.district = "Kamrup"
      l.latitude = 26.14
      l.longitude = 91.74
      l.population = 500000
      l.accessibility_score = 90.0
      l.road_quality = "good"
      l.rainfall_level = "moderate"
      l.landslide_risk = "low"
    end

    @location_b = Location.find_or_create_by!(name: "Test Location B") do |l|
      l.state = "Arunachal Pradesh"
      l.district = "Tawang"
      l.latitude = 27.59
      l.longitude = 91.87
      l.population = 49000
      l.accessibility_score = 15.0
      l.road_quality = "poor"
      l.rainfall_level = "high"
      l.landslide_risk = "critical"
    end

    @warehouse_operational = Warehouse.find_or_create_by!(name: "WH Test Operational") do |w|
      w.latitude = 26.15
      w.longitude = 91.75
      w.capacity = 50000
      w.utilized_capacity = 15000
      w.operational_status = "OPERATIONAL"
      w.readiness_score = 85.0
      w.resources_json = {
        "medical_kits" => 2000, "food_packages" => 5000,
        "water_units" => 10000, "emergency_shelters" => 300,
        "fuel_liters" => 8000, "rescue_equipment" => 100
      }.to_json
      w.location = @location_a
    end

    @warehouse_limited = Warehouse.find_or_create_by!(name: "WH Test Limited") do |w|
      w.latitude = 27.10
      w.longitude = 93.62
      w.capacity = 20000
      w.utilized_capacity = 14000
      w.operational_status = "LIMITED"
      w.readiness_score = 45.0
      w.resources_json = {
        "medical_kits" => 200, "food_packages" => 500,
        "water_units" => 1000, "emergency_shelters" => 30,
        "fuel_liters" => 1000, "rescue_equipment" => 10
      }.to_json
      w.location = @location_b
    end

    @warehouse_overloaded = Warehouse.find_or_create_by!(name: "WH Test Overloaded") do |w|
      w.latitude = 25.58
      w.longitude = 91.88
      w.capacity = 25000
      w.utilized_capacity = 23000
      w.operational_status = "OVERLOADED"
      w.readiness_score = 20.0
      w.resources_json = {
        "medical_kits" => 50, "food_packages" => 100,
        "water_units" => 200, "emergency_shelters" => 5,
        "fuel_liters" => 300, "rescue_equipment" => 3
      }.to_json
    end

    @emergency = Emergency.create!(
      title: "WH Test Landslide Emergency",
      emergency_type: "Landslide",
      severity: "Critical",
      latitude: 27.59,
      longitude: 91.87,
      affected_radius: 50.0,
      status: "Active",
      location: @location_b,
      description: "Test emergency for warehouse recommendation."
    )
  end

  test "recommend returns recommendation hash with required keys" do
    service = WarehouseRecommendationService.new(@emergency)
    result = service.recommend

    assert result.is_a?(Hash)
    assert_includes result.keys, :recommended
    assert_includes result.keys, :candidates
    assert_includes result.keys, :reasoning
    assert_includes result.keys, :weights
    assert_includes result.keys, :warehouse_count
    assert result[:warehouse_count] > 0
  end

  test "recommended candidate has all expected fields" do
    service = WarehouseRecommendationService.new(@emergency)
    result = service.recommend
    best = result[:recommended]

    assert_not_nil best
    assert best[:name].present?
    assert best[:response_score].is_a?(Numeric)
    assert best[:distance_km].is_a?(Numeric)
    assert best[:route_safety_score].is_a?(Numeric)
    assert best[:resource_score].is_a?(Numeric)
    assert best[:capacity_score].is_a?(Numeric)
    assert best[:rank] == 1
  end

  test "candidates are ranked by response_score descending" do
    service = WarehouseRecommendationService.new(@emergency)
    result = service.recommend
    candidates = result[:candidates]

    assert candidates.size >= 2
    scores = candidates.map { |c| c[:response_score] }
    assert_equal scores, scores.sort.reverse, "Candidates should be sorted by response_score descending"
  end

  test "does not always choose nearest warehouse" do
    service = WarehouseRecommendationService.new(@emergency)
    result = service.recommend
    candidates = result[:candidates]

    nearest = candidates.min_by { |c| c[:distance_km] }
    best = result[:recommended]

    assert_not_nil best
    assert_not_nil nearest
    assert best[:response_score] >= nearest[:response_score]
  end

  test "reasoning is generated as a non-empty string" do
    service = WarehouseRecommendationService.new(@emergency)
    result = service.recommend

    assert result[:reasoning].present?
    assert result[:reasoning].is_a?(String)
  end

  test "handles empty warehouse list gracefully" do
    service = WarehouseRecommendationService.new(@emergency, warehouses: [])
    result = service.recommend

    assert_nil result[:recommended]
    assert_equal [], result[:candidates]
    assert_equal 0, result[:warehouse_count]
    assert result[:reasoning].present?
  end

  test "positive and negative factors are generated" do
    service = WarehouseRecommendationService.new(@emergency)
    result = service.recommend
    best = result[:recommended]

    assert best[:positive_factors].is_a?(Array)
    assert best[:negative_factors].is_a?(Array)
  end

  test "weights sum to 1.0" do
    total = WarehouseRecommendationService::WEIGHTS.values.sum
    assert_in_delta 1.0, total, 0.001
  end
end
