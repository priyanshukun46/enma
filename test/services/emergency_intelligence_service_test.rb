require "test_helper"

class EmergencyIntelligenceServiceTest < ActiveSupport::TestCase
  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    @guwahati = Location.find_or_create_by!(name: "Guwahati Central") do |l|
      l.state = "Assam"
      l.district = "Kamrup"
      l.latitude = 26.1445
      l.longitude = 91.7362
      l.population = 950000
      l.accessibility_score = 92.0
      l.road_quality = "excellent"
      l.rainfall_level = "low"
      l.landslide_risk = "low"
    end

    @tawang = Location.find_or_create_by!(name: "Tawang Sector") do |l|
      l.state = "Arunachal Pradesh"
      l.district = "Tawang"
      l.latitude = 27.5855
      l.longitude = 91.8679
      l.population = 49000
      l.accessibility_score = 15.0
      l.road_quality = "poor"
      l.rainfall_level = "high"
      l.landslide_risk = "critical"
    end

    @warehouse = Warehouse.find_or_create_by!(name: "Guwahati Regional Logistics Depot") do |w|
      w.latitude = 26.1500
      w.longitude = 91.7400
      w.capacity = 50000
      w.utilized_capacity = 15000
      w.operational_status = "OPERATIONAL"
      w.readiness_score = 85.0
      w.resources_json = {
        "medical_kits" => 2000, "food_packages" => 5000,
        "water_units" => 10000, "emergency_shelters" => 300,
        "fuel_liters" => 8000, "rescue_equipment" => 100
      }.to_json
      w.location = @guwahati
    end

    @emergency = Emergency.create!(
      title: "Critical Monsoon Landslide near Tawang",
      emergency_type: "Landslide",
      severity: "Critical",
      latitude: 27.5855,
      longitude: 91.8679,
      affected_radius: 50.0,
      status: "Active",
      location: @tawang,
      description: "Severe slope failure blocking arterial transit corridor."
    )
  end

  teardown do
    Rails.cache = @original_cache
  end

  # =========================================================================
  # 1. Severity Intelligence Scoring Tests
  # =========================================================================
  test "calculates emergency severity score (0-100) and classifies level" do
    service = EmergencyIntelligenceService.new(@emergency)
    severity_intel = service.calculate_emergency_severity

    assert_not_nil severity_intel
    assert severity_intel[:severity_score] >= 10.0
    assert severity_intel[:severity_score] <= 100.0
    assert_includes %w[CRITICAL HIGH MODERATE LOW], severity_intel[:severity_level]
    assert_includes severity_intel[:explanation], "Severity assessed as"
  end

  # =========================================================================
  # 2. Affected Community Detection & Classification Tests
  # =========================================================================
  test "detects and classifies affected communities by spatial proximity" do
    service = EmergencyIntelligenceService.new(@emergency)
    communities = service.detect_and_classify_affected_communities(85.0)

    assert communities.any?
    first_comm = communities.first

    assert_equal 1, first_comm[:rank]
    assert_not_nil first_comm[:name]
    assert_not_nil first_comm[:distance_km]
    assert_includes ["Directly Affected", "Potentially Affected", "Monitoring Required"], first_comm[:spatial_status]
    assert first_comm[:priority_score] >= 0.0 && first_comm[:priority_score] <= 100.0
  end

  # =========================================================================
  # 3. Community Priority Ranking Tests
  # =========================================================================
  test "calculates multi-factor community priority score and assigns priority tier" do
    service = EmergencyIntelligenceService.new(@emergency)
    priority_data = service.calculate_community_priority(@tawang, 5.0, 90.0)

    assert priority_data[:priority_score] >= 0.0
    assert priority_data[:priority_score] <= 100.0
    assert_includes ["Immediate Response", "High Priority", "Moderate Priority", "Monitoring"], priority_data[:priority_level]
    assert_not_nil priority_data[:breakdown][:population_component]
    assert_not_nil priority_data[:breakdown][:severity_component]
  end

  # =========================================================================
  # 4. Multi-Criteria Warehouse Recommendation Tests
  # =========================================================================
  test "selects optimal warehouse with explainable reasoning" do
    service = EmergencyIntelligenceService.new(@emergency)
    wh_rec = service.select_optimal_warehouse

    assert_not_nil wh_rec
    assert_equal "Guwahati Regional Logistics Depot", wh_rec[:name]
    assert wh_rec[:recommendation_score] >= 0.0
    assert_includes wh_rec[:selection_reasoning], "recommended"
  end

  # =========================================================================
  # 5. Smart Emergency Route Intelligence Tests
  # =========================================================================
  test "calculates emergency dispatch route with ETA and risk score" do
    service = EmergencyIntelligenceService.new(@emergency)
    top_community = { location: @tawang, id: @tawang.id, name: @tawang.name }
    route = service.calculate_emergency_dispatch_route(@warehouse, top_community)

    assert_not_nil route
    assert_equal @warehouse.name, route[:origin_name]
    assert_equal @tawang.name, route[:destination_name]
    assert route[:distance_km] > 0.0
    assert_not_nil route[:estimated_time]
    assert route[:risk_score] >= 0.0
  end

  # =========================================================================
  # 6. Response Plan Generation & Persistence Tests
  # =========================================================================
  test "generates and persists structured ResponsePlan record with formatted briefing" do
    service = EmergencyIntelligenceService.new(@emergency)
    plan = service.generate_and_persist_plan!

    assert_not_nil plan
    assert_equal @emergency.id, plan.emergency_id
    assert_equal "active", plan.status
    assert plan.affected_communities_count >= 1
    assert plan.total_population_at_risk > 0
    assert_not_nil plan.severity_level
    assert plan.primary_risks.any?
    assert plan.action_items.any?

    briefing = plan.formatted_briefing
    assert briefing.match?(/ResQWay|ENMA AI/)
    assert_includes briefing, @emergency.title
    assert_includes briefing, plan.warehouse_name
  end

  # =========================================================================
  # 7. Fallback Behavior Tests
  # =========================================================================
  test "handles external routing and weather failure with graceful fallback" do
    service = EmergencyIntelligenceService.new(@emergency)

    original_osrm = RoutingService.instance_method(:fetch_osrm_routes)
    original_weather = WeatherService.instance_method(:fetch_from_api)

    begin
      RoutingService.define_method(:fetch_osrm_routes) { |*| raise Net::ReadTimeout, "OSRM Timeout" }
      WeatherService.define_method(:fetch_from_api) { |*| raise Net::ReadTimeout, "Weather Timeout" }

      plan = service.generate_and_persist_plan!

      assert_not_nil plan
      assert_equal "active", plan.status
      assert plan.affected_communities_count >= 1
    ensure
      RoutingService.define_method(:fetch_osrm_routes, original_osrm)
      WeatherService.define_method(:fetch_from_api, original_weather)
    end
  end
end
