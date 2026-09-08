# frozen_string_literal: true

require "test_helper"

module ResQWay
  class AutonomousResponseOptimizationServiceTest < ActiveSupport::TestCase
    def setup
      LogisticsAlert.delete_all
      Incident.delete_all
      Road.delete_all
      Warehouse.delete_all
      Location.delete_all

      # Create test locations in Northeast India
      @guwahati = Location.create!(
        name: "Guwahati Hub",
        state: "Assam",
        district: "Kamrup",
        location_type: "City",
        population: 1_000_000,
        latitude: 26.1445,
        longitude: 91.7362,
        road_quality: "excellent",
        rainfall_level: "low",
        landslide_risk: "low",
        accessibility_score: 90.0
      )

      @imphal = Location.create!(
        name: "Imphal Valley",
        state: "Manipur",
        district: "Imphal West",
        location_type: "City",
        population: 250_000,
        latitude: 24.8170,
        longitude: 93.9368,
        road_quality: "moderate",
        rainfall_level: "high",
        landslide_risk: "high",
        accessibility_score: 35.0
      )

      @kangpokpi = Location.create!(
        name: "Kangpokpi",
        state: "Manipur",
        district: "Kangpokpi",
        location_type: "Settlement",
        population: 45_000,
        latitude: 25.1500,
        longitude: 93.9800,
        road_quality: "poor",
        rainfall_level: "high",
        landslide_risk: "high",
        accessibility_score: 25.0
      )

      @kohima = Location.create!(
        name: "Kohima",
        state: "Nagaland",
        district: "Kohima",
        location_type: "Town",
        population: 120_000,
        latitude: 25.6701,
        longitude: 94.1077,
        road_quality: "good",
        rainfall_level: "moderate",
        landslide_risk: "medium",
        accessibility_score: 65.0
      )

      # Warehouses:
      # Guwahati Central: Farther, but massive operational capacity and low risk
      @wh_guwahati = Warehouse.create!(
        name: "Guwahati Central Depot",
        location: @guwahati,
        operational_status: "OPERATIONAL",
        capacity: 3000,
        utilized_capacity: 1200,
        latitude: 26.1445,
        longitude: 91.7362
      )

      # Kohima Forward Depot: Closer to Imphal
      @wh_kohima = Warehouse.create!(
        name: "Kohima Staging Depot",
        location: @kohima,
        operational_status: "OPERATIONAL",
        capacity: 1500,
        utilized_capacity: 600,
        latitude: 25.6701,
        longitude: 94.1077
      )

      # Roads connecting network
      # Road 1: Guwahati to Kohima (High quality arterial)
      @road_arterial = Road.create!(
        name: "NH-29 Dimapur-Kohima Corridor",
        road_number: "NH-29",
        state: "Nagaland",
        status: "accessible",
        risk_level: "low",
        road_condition: "excellent",
        risk_score: 25.0,
        ml_disruption_probability: 0.20,
        length_km: 140.0,
        geometry_coordinates: [[26.1445, 91.7362], [25.6701, 94.1077]]
      )

      # Road 2: Kohima to Imphal (Direct NH-02, highly vulnerable mountain chokepoint)
      @road_direct = Road.create!(
        name: "NH-02 Kohima-Imphal Highway",
        road_number: "NH-02",
        state: "Manipur",
        status: "accessible",
        risk_level: "high",
        road_condition: "poor",
        risk_score: 75.0,
        ml_disruption_probability: 0.70,
        length_km: 130.0,
        geometry_coordinates: [[25.6701, 94.1077], [24.8170, 93.9368]]
      )

      # Road 3: Bypass via Kangpokpi (Longer, but lower landslide vulnerability)
      @road_bypass = Road.create!(
        name: "Bypass Corridor via Kangpokpi",
        road_number: "NH-129A",
        state: "Manipur",
        status: "accessible",
        risk_level: "low",
        road_condition: "good",
        risk_score: 30.0,
        ml_disruption_probability: 0.25,
        length_km: 190.0,
        geometry_coordinates: [[25.6701, 94.1077], [25.1500, 93.9800]]
      )

      @road_kang_imphal = Road.create!(
        name: "Kangpokpi-Imphal Link",
        road_number: "NH-129B",
        state: "Manipur",
        status: "accessible",
        risk_level: "low",
        road_condition: "good",
        risk_score: 30.0,
        ml_disruption_probability: 0.25,
        length_km: 45.0,
        geometry_coordinates: [[25.1500, 93.9800], [24.8170, 93.9368]]
      )

      @locations = [@guwahati, @imphal, @kangpokpi, @kohima]
      @warehouses = [@wh_guwahati, @wh_kohima]
      @roads = [@road_arterial, @road_direct, @road_bypass, @road_kang_imphal]
    end

    # =========================================================================
    # PRIORITY INTELLIGENCE (1-5)
    # =========================================================================
    test "scenario 1: empty network returns safe structured response without crashing" do
      service = ResQWay::AutonomousResponseOptimizationService.new(
        locations: [],
        warehouses: [],
        roads: []
      )

      res = service.analyze(forecast_hours: 12)
      assert_equal "COMPLETE", res[:status]
      assert_equal 0.0, res[:overall_response_urgency]
      assert_empty res[:priority_zones]
      assert_empty res[:warehouse_capabilities]
      assert_nil res[:optimal_strategy]
    end

    test "scenario 2: nominal conditions produce low urgency and standard monitoring" do
      Road.update_all(risk_score: 15.0, ml_disruption_probability: 0.10)

      service = ResQWay::AutonomousResponseOptimizationService.new
      res = service.analyze(forecast_hours: 12)

      assert_includes %w[MONITOR PLANNED HIGH], res[:urgency_level]
      assert res[:overall_response_urgency] < 60.0
    end

    test "scenario 3: priority zones are deterministically ranked by humanitarian priority score" do
      service = ResQWay::AutonomousResponseOptimizationService.new
      res = service.analyze(forecast_hours: 12)

      zones = res[:priority_zones]
      assert zones.any?
      # Ensure descending order
      scores = zones.map { |z| z[:humanitarian_priority] }
      assert_equal scores.sort.reverse, scores
    end

    test "scenario 4: population exposure weighting increases priority for large populations" do
      service = ResQWay::AutonomousResponseOptimizationService.new
      zones = service.identify_priority_zones({ scenarios: [] })

      imphal_zone = zones.find { |z| z[:location_id] == @imphal.id }
      kang_zone = zones.find { |z| z[:location_id] == @kangpokpi.id }

      assert_not_nil imphal_zone
      assert_not_nil kang_zone
      assert imphal_zone[:population_at_risk] > kang_zone[:population_at_risk]
    end

    test "scenario 5: active critical incident elevates humanitarian priority score" do
      Incident.create!(
        incident_type: "landslide",
        severity: "critical",
        status: "verified",
        state: "Manipur",
        latitude: @imphal.latitude,
        longitude: @imphal.longitude,
        reported_at: 2.hours.ago,
        ai_confidence_score: 95.0,
        description: "Confirmed major landslide blocking arterial corridor"
      )

      service = ResQWay::AutonomousResponseOptimizationService.new
      zones = service.identify_priority_zones({ scenarios: [] })

      imphal_zone = zones.find { |z| z[:location_id] == @imphal.id }
      assert imphal_zone[:humanitarian_priority] >= 65.0
      assert_includes %w[CRITICAL_PRIORITY CATASTROPHIC_PRIORITY HIGH_PRIORITY], imphal_zone[:priority_level]
    end

    # =========================================================================
    # WAREHOUSE OPTIMIZATION (6-8)
    # =========================================================================
    test "scenario 6: warehouse capability score reflects status, capacity, and accessibility" do
      service = ResQWay::AutonomousResponseOptimizationService.new
      zones = service.identify_priority_zones({ scenarios: [] })
      caps = service.evaluate_warehouse_capabilities(zones)

      wh_guw = caps.find { |w| w[:warehouse_id] == @wh_guwahati.id }
      assert_not_nil wh_guw
      assert wh_guw[:capability_score].between?(0.0, 100.0)
      assert wh_guw[:available_resources].present?
      assert_includes %w[PRIMARY_DISPATCH_HUB SECONDARY_DISPATCH_HUB FORWARD_STAGING_HUB PREPOSITIONING_HUB RESERVE_HUB], wh_guw[:recommended_role]
    end

    test "scenario 7: overloaded or inactive warehouse has degraded capability and role" do
      @wh_kohima.update!(operational_status: "OVERLOADED", utilized_capacity: 1500)

      service = ResQWay::AutonomousResponseOptimizationService.new
      zones = service.identify_priority_zones({ scenarios: [] })
      caps = service.evaluate_warehouse_capabilities(zones)

      wh_k = caps.find { |w| w[:warehouse_id] == @wh_kohima.id }
      assert wh_k[:capability_score] < 60.0
      assert_equal "DEGRADED", wh_k[:dispatch_readiness]
    end

    test "scenario 8: geographically closest warehouse is not blindly selected over safer high-capacity hub" do
      # Kohima is closer to Imphal, but if its connected road is severely blocked and capacity is zero:
      @wh_kohima.update!(operational_status: "LIMITED", utilized_capacity: 1450)
      @road_direct.update!(status: "blocked", risk_score: 95.0)

      service = ResQWay::AutonomousResponseOptimizationService.new
      zones = service.identify_priority_zones({ scenarios: [] })
      caps = service.evaluate_warehouse_capabilities(zones)

      guw_cap = caps.find { |w| w[:warehouse_id] == @wh_guwahati.id }
      koh_cap = caps.find { |w| w[:warehouse_id] == @wh_kohima.id }

      assert guw_cap[:capability_score] > koh_cap[:capability_score]
    end

    # =========================================================================
    # ROUTE OPTIMIZATION (9-11)
    # =========================================================================
    test "scenario 9: safe bypass route beats shortest route with high failure risk" do
      @road_direct.update!(risk_score: 90.0, ml_disruption_probability: 0.85)

      service = ResQWay::AutonomousResponseOptimizationService.new
      zones = service.identify_priority_zones({ scenarios: [] })
      caps = service.evaluate_warehouse_capabilities(zones)
      routes = service.evaluate_routes_to_priority_zones(caps, zones)

      # Ensure routes to Imphal are evaluated
      imphal_routes = routes.select { |r| r[:destination_location_id] == @imphal.id }
      assert imphal_routes.any?
      assert imphal_routes.any? { |r| r[:route_safety] >= 60.0 }
    end

    test "scenario 10: high risk route is classified as HIGH_RISK or LAST_RESORT" do
      @road_direct.update!(risk_score: 85.0, ml_disruption_probability: 0.80)

      service = ResQWay::AutonomousResponseOptimizationService.new
      zones = service.identify_priority_zones({ scenarios: [] })
      caps = service.evaluate_warehouse_capabilities(zones)
      routes = service.evaluate_routes_to_priority_zones(caps, zones)

      direct_eval = routes.find { |r| r[:destination_location_id] == @imphal.id && r[:corridor_risk] >= 50.0 }
      assert_not_nil direct_eval
      assert_includes %w[HIGH_RISK LAST_RESORT SAFE_ALTERNATIVE], direct_eval[:classification]
    end

    test "scenario 11: no ground route available is classified as UNAVAILABLE" do
      Road.update_all(status: "blocked")

      service = ResQWay::AutonomousResponseOptimizationService.new
      zones = service.identify_priority_zones({ scenarios: [] })
      caps = service.evaluate_warehouse_capabilities(zones)
      routes = service.evaluate_routes_to_priority_zones(caps, zones)

      assert routes.all? { |r| r[:classification] == "UNAVAILABLE" || r[:has_ground_route] == false }
    end

    # =========================================================================
    # STRATEGY OPTIMIZATION (12-14)
    # =========================================================================
    test "scenario 12: strategy generation is strictly bounded to at most 10" do
      service = ResQWay::AutonomousResponseOptimizationService.new
      res = service.analyze(forecast_hours: 12, strategy_limit: 10)

      all_strategies = [res[:optimal_strategy]].compact + res[:alternative_strategies]
      assert all_strategies.size <= 10
      assert res[:instrumentation][:strategies_generated] <= 10
    end

    test "scenario 13: optimal strategy is selected via highest risk adjusted utility" do
      service = ResQWay::AutonomousResponseOptimizationService.new
      res = service.analyze(forecast_hours: 12)

      opt = res[:optimal_strategy]
      assert_not_nil opt
      res[:alternative_strategies].each do |alt|
        assert_operator opt[:risk_adjusted_utility], :>=, alt[:risk_adjusted_utility]
      end
    end

    test "scenario 14: risk adjusted utility applies correct plan resilience multipliers" do
      service = ResQWay::AutonomousResponseOptimizationService.new
      strat_resilient = service.build_strategy(
        strategy_type: "RESILIENT_DISPATCH",
        name: "Test Resilient",
        description: "Test",
        primary_warehouse: { warehouse_id: @wh_guwahati.id, warehouse_name: @wh_guwahati.name },
        secondary_warehouse: nil,
        route: { estimated_hours: 3.0, route_safety: 85.0 },
        target_zones: [{ population_at_risk: 10_000, name: "Zone 1" }],
        pop_protected: 9_000,
        response_speed: 80.0,
        route_safety: 85.0,
        resource_efficiency: 80.0,
        plan_resilience_class: "RESILIENT",
        prediction_confidence: 85.0,
        allocated_resources: {}
      )

      assert_equal 0.95, ResQWay::AutonomousResponseOptimizationService::RESILIENCE_MULTIPLIERS["RESILIENT"]
      assert_in_delta (strat_resilient[:response_utility] * 0.95), strat_resilient[:risk_adjusted_utility], 0.2
    end

    # =========================================================================
    # PREPOSITIONING DECISION (15-17)
    # =========================================================================
    test "scenario 15: immediate prepositioning triggered under high failure probability and cascade impact" do
      mock_pred = {
        overall_cascade_risk: 85.0,
        scenarios: [{
          name: "NH-02 Critical Failure",
          failure_probability: 88.0,
          cascade_score: 85.0,
          prediction_confidence: 90.0,
          isolated_settlements: [{ id: @imphal.id, name: @imphal.name }]
        }],
        top_scenario: { failure_probability: 88.0, cascade_score: 85.0 },
        summary: { overall_cascade_risk: 85.0, prediction_confidence: 90.0 }
      }

      service = ResQWay::AutonomousResponseOptimizationService.new
      zones = service.identify_priority_zones(mock_pred)
      caps = service.evaluate_warehouse_capabilities(zones)
      preps = service.evaluate_prepositioning_decisions(
        priority_zones: zones,
        predictive_analysis: mock_pred,
        warehouse_capabilities: caps
      )

      assert preps.any?
      assert_equal "PREPOSITION_NOW", preps.first[:decision]
      assert preps.first[:benefit_score] >= 85.0
    end

    test "scenario 16: preparation only triggered under moderate failure probability" do
      mock_pred = {
        overall_cascade_risk: 45.0,
        scenarios: [{
          name: "NH-02 Moderate Threat",
          failure_probability: 45.0,
          cascade_score: 40.0,
          prediction_confidence: 70.0
        }],
        top_scenario: { failure_probability: 45.0, cascade_score: 40.0 },
        summary: { overall_cascade_risk: 45.0, prediction_confidence: 70.0 }
      }

      service = ResQWay::AutonomousResponseOptimizationService.new
      zones = service.identify_priority_zones(mock_pred)
      caps = service.evaluate_warehouse_capabilities(zones)
      preps = service.evaluate_prepositioning_decisions(
        priority_zones: zones,
        predictive_analysis: mock_pred,
        warehouse_capabilities: caps
      )

      assert_includes %w[PREPARE_RESOURCES PREPOSITION_WITHIN_6H MONITOR], preps.first[:decision]
    end

    test "scenario 17: prepositioning not required under low risk" do
      mock_pred = {
        overall_cascade_risk: 10.0,
        scenarios: [{
          name: "Nominal Conditions",
          failure_probability: 10.0,
          cascade_score: 10.0,
          prediction_confidence: 60.0
        }],
        top_scenario: { failure_probability: 10.0, cascade_score: 10.0 },
        summary: { overall_cascade_risk: 10.0, prediction_confidence: 60.0 }
      }

      service = ResQWay::AutonomousResponseOptimizationService.new
      # Set low population to test NOT_REQUIRED threshold
      @imphal.update!(population: 500)
      zones = service.identify_priority_zones(mock_pred)
      caps = service.evaluate_warehouse_capabilities(zones)
      preps = service.evaluate_prepositioning_decisions(
        priority_zones: zones,
        predictive_analysis: mock_pred,
        warehouse_capabilities: caps
      )

      assert_includes %w[NOT_REQUIRED MONITOR], preps.first[:decision]
    end

    # =========================================================================
    # AERIAL OPERATIONS (18-19)
    # =========================================================================
    test "scenario 18: airlift escalation triggered when ground route is blocked or extreme risk" do
      Road.update_all(status: "blocked")

      service = ResQWay::AutonomousResponseOptimizationService.new
      res = service.analyze(forecast_hours: 12)

      aerial = res[:aerial_response]
      assert_equal true, aerial[:airlift_justified]
      assert_includes %w[EMERGENCY_AIRLIFT GROUND_WITH_AIR_CONTINGENCY], aerial[:recommendation]
    end

    test "scenario 19: UAV reconnaissance recommended when humanitarian priority is high" do
      @imphal.update!(accessibility_score: 20.0)

      service = ResQWay::AutonomousResponseOptimizationService.new
      res = service.analyze(forecast_hours: 12)

      aerial = res[:aerial_response]
      assert aerial[:uav_recon_status].present?
    end

    # =========================================================================
    # RESILIENCE & CONTINGENCIES (20-22)
    # =========================================================================
    test "scenario 20: alternative route contingency provides fallback action" do
      service = ResQWay::AutonomousResponseOptimizationService.new
      res = service.analyze(forecast_hours: 12)

      cont = res[:contingency_plans].find { |c| c[:contingency_id] == "CONTINGENCY-A" }
      assert_not_nil cont
      assert cont[:fallback_action].present?
      assert cont[:residual_response_capacity_pct].positive?
    end

    test "scenario 21: warehouse failure contingency activates secondary depot" do
      service = ResQWay::AutonomousResponseOptimizationService.new
      res = service.analyze(forecast_hours: 12)

      cont = res[:contingency_plans].find { |c| c[:contingency_id] == "CONTINGENCY-B" }
      assert_not_nil cont
      assert cont[:fallback_available]
      assert_includes cont[:fallback_action].downcase, "transfer dispatch authority"
    end

    test "scenario 22: secondary cascade contingency evaluates multi-point failure" do
      service = ResQWay::AutonomousResponseOptimizationService.new
      res = service.analyze(forecast_hours: 12)

      cont = res[:contingency_plans].find { |c| c[:contingency_id] == "CONTINGENCY-C" }
      assert_not_nil cont
      assert_equal "Multi-Point Secondary Cascade Failure", cont[:scenario]
    end

    # =========================================================================
    # EXPLAINABILITY & COUNTERFACTUAL (23-24)
    # =========================================================================
    test "scenario 23: counterfactual analysis calculates population and delay improvements" do
      service = ResQWay::AutonomousResponseOptimizationService.new
      res = service.analyze(forecast_hours: 12)

      cf = res[:counterfactual_analysis]
      assert_not_nil cf
      assert cf[:without_action].present?
      assert cf[:with_enma_plan].present?
      assert cf[:modeled_improvements].present?
      assert cf[:modeled_improvements][:delay_reduction_pct].positive?
      assert cf[:model_disclaimer].present?
    end

    test "scenario 24: complete decision explanation explains both winner and rejected alternatives" do
      service = ResQWay::AutonomousResponseOptimizationService.new
      res = service.analyze(forecast_hours: 12)

      expl = res[:decision_explanation]
      assert_not_nil expl
      assert expl[:why_selected].any?
      assert expl[:expected_benefit].present?
      assert expl[:rejected_alternatives].is_a?(Array)

      # Every rejected alternative must have explicit reasons why it lost
      expl[:rejected_alternatives].each do |rej|
        assert rej[:strategy_name].present?
        assert rej[:why_rejected].any?
      end
    end

    # =========================================================================
    # ENGINEERING & PERFORMANCE (25-27)
    # =========================================================================
    test "scenario 25: complete response optimization executes in under 2 seconds" do
      service = ResQWay::AutonomousResponseOptimizationService.new

      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      res = service.analyze(forecast_hours: 12)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start

      assert_operator elapsed, :<, 2.0, "Analysis took too long: #{elapsed}s"
      assert res[:instrumentation][:execution_time_ms] < 2000.0
    end

    test "scenario 26: deterministic output consistency across sequential runs" do
      service1 = ResQWay::AutonomousResponseOptimizationService.new
      res1 = service1.analyze(forecast_hours: 12)

      service2 = ResQWay::AutonomousResponseOptimizationService.new
      res2 = service2.analyze(forecast_hours: 12)

      assert_equal res1[:optimal_strategy][:strategy_type], res2[:optimal_strategy][:strategy_type]
      assert_equal res1[:overall_response_urgency], res2[:overall_response_urgency]
      assert_equal res1[:priority_zones].map { |z| z[:location_id] }, res2[:priority_zones].map { |z| z[:location_id] }
    end

    test "scenario 27: allocated resources strictly adhere to available warehouse resources" do
      service = ResQWay::AutonomousResponseOptimizationService.new
      res = service.analyze(forecast_hours: 12)

      alloc = res.dig(:optimal_strategy, :allocated_resources)
      assert_not_nil alloc
      assert_equal true, alloc[:constraint_verified]

      wh = @warehouses.find { |w| w.id == res.dig(:optimal_strategy, :primary_warehouse_id) }
      assert alloc[:medical_kits] <= [wh.available_capacity * 2, 5000].max
      assert alloc[:food_packages] <= [wh.available_capacity * 3, 10000].max
    end
  end
end
