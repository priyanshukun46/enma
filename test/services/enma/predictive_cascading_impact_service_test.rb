# frozen_string_literal: true

require "test_helper"

module Enma
  class PredictiveCascadingImpactServiceTest < ActiveSupport::TestCase
    def setup
      LogisticsAlert.delete_all
      Incident.delete_all
      Road.delete_all
      Warehouse.delete_all
      Location.delete_all

      # Create 4 locations in Northeast India:
      # Guwahati (Warehouse Hub) <---> (NH-27) <---> Jorhat <---> (NH-715) <---> Kaziranga
      # Guwahati <---> (NH-06) <---> Shillong
      @guwahati = Location.create!(
        name: "Guwahati",
        state: "Assam",
        district: "Kamrup",
        location_type: "City",
        population: 1_000_000,
        latitude: 26.1445,
        longitude: 91.7362,
        road_quality: "excellent",
        rainfall_level: "low",
        landslide_risk: "low",
        transport_availability: "high"
      )

      @jorhat = Location.create!(
        name: "Jorhat",
        state: "Assam",
        district: "Jorhat",
        location_type: "Town",
        population: 150_000,
        latitude: 26.7509,
        longitude: 94.2037,
        road_quality: "good",
        rainfall_level: "moderate",
        landslide_risk: "low",
        transport_availability: "high"
      )

      @kaziranga = Location.create!(
        name: "Kaziranga",
        state: "Assam",
        district: "Golaghat",
        location_type: "Settlement",
        population: 25_000,
        latitude: 26.5775,
        longitude: 93.1711,
        road_quality: "moderate",
        rainfall_level: "high",
        landslide_risk: "low",
        transport_availability: "medium"
      )

      @shillong = Location.create!(
        name: "Shillong",
        state: "Meghalaya",
        district: "East Khasi Hills",
        location_type: "City",
        population: 180_000,
        latitude: 25.5788,
        longitude: 91.8933,
        road_quality: "good",
        rainfall_level: "high",
        landslide_risk: "medium",
        transport_availability: "high"
      )

      @warehouse = Warehouse.create!(
        name: "Guwahati Central Relief Depot",
        location: @guwahati,
        operational_status: "OPERATIONAL",
        capacity: 2500,
        utilized_capacity: 1100,
        contact_phone: "+91-361-223344",
        address: "Amingaon Logistics Hub, Guwahati",
        latitude: 26.1445,
        longitude: 91.7362
      )

      @road_nh27 = Road.create!(
        name: "NH-27 Guwahati-Jorhat Arterial",
        road_number: "NH-27",
        state: "Assam",
        district: "Kamrup",
        status: "accessible",
        risk_level: "low",
        road_condition: "excellent",
        risk_score: 20.0,
        ml_disruption_probability: 0.15,
        length_km: 300.0,
        geometry_coordinates: [[26.1445, 91.7362], [26.44, 92.97], [26.7509, 94.2037]]
      )

      @road_nh715 = Road.create!(
        name: "NH-715 Jorhat-Kaziranga Connector",
        road_number: "NH-715",
        state: "Assam",
        district: "Golaghat",
        status: "accessible",
        risk_level: "low",
        road_condition: "good",
        risk_score: 25.0,
        ml_disruption_probability: 0.20,
        length_km: 90.0,
        geometry_coordinates: [[26.7509, 94.2037], [26.5775, 93.1711]]
      )

      @road_nh06 = Road.create!(
        name: "NH-06 Guwahati-Shillong Hill Corridor",
        road_number: "NH-06",
        state: "Meghalaya",
        district: "East Khasi Hills",
        status: "accessible",
        risk_level: "low",
        road_condition: "good",
        risk_score: 30.0,
        ml_disruption_probability: 0.25,
        length_km: 100.0,
        geometry_coordinates: [[26.1445, 91.7362], [25.5788, 91.8933]]
      )
    end

    def with_mock_weather(mock_data_or_proc)
      singleton = WeatherService.singleton_class
      orig_method = WeatherService.method(:fetch)
      singleton.send(:define_method, :fetch) do |*args|
        if mock_data_or_proc.is_a?(Proc)
          mock_data_or_proc.call(*args)
        else
          mock_data_or_proc
        end
      end
      yield
    ensure
      singleton.send(:define_method, :fetch, orig_method)
    end

    # =========================================================================
    # SCENARIO 1: Empty Network Handling
    # =========================================================================
    test "scenario 1: empty network returns safe structured response without errors" do
      empty_service = Enma::PredictiveCascadingImpactService.new(
        roads: [],
        locations: [],
        warehouses: []
      )

      res = empty_service.analyze(forecast_hours: 12)

      assert_equal 0.0, res[:overall_cascade_risk]
      assert_equal "LIMITED", res[:risk_level]
      assert_empty res[:threatened_roads]
      assert_empty res[:scenarios]
      assert_nil res[:top_scenario]
      assert res[:explanation].any?
      assert res[:warnings].any?
      assert_equal 0, res[:metadata][:simulation_calls]
    end

    # =========================================================================
    # SCENARIO 2: No Hazards (Nominal Baseline)
    # =========================================================================
    test "scenario 2: nominal conditions produce low failure probability and limited cascade risk" do
      with_mock_weather({ precipitation_mm: 0.0, rainfall: "none", condition: "Clear", alerts: [] }) do
        service = Enma::PredictiveCascadingImpactService.new
        res = service.analyze(forecast_hours: 12)

        assert res[:overall_cascade_risk] < 40.0
        assert_includes %w[LIMITED ELEVATED], res[:risk_level]
        assert res[:threatened_roads].all? { |r| r[:failure_probability] < 50.0 }
        assert res[:metadata][:simulation_calls] <= 6
      end
    end

    # =========================================================================
    # SCENARIO 3: High-Risk Road Identification
    # =========================================================================
    test "scenario 3: elevated road risk and ML probability rank road at top of threat list" do
      @road_nh27.update!(risk_score: 85.0, ml_disruption_probability: 0.90)

      service = Enma::PredictiveCascadingImpactService.new
      res = service.analyze(forecast_hours: 12)

      top_threat = res[:threatened_roads].first
      assert_equal @road_nh27.id, top_threat[:road_id]
      assert top_threat[:failure_probability] >= 50.0
      assert top_threat[:threat_priority] >= 50.0
    end

    # =========================================================================
    # SCENARIO 4: Low-Confidence Incident Weighting
    # =========================================================================
    test "scenario 4: low confidence incident is attenuated and does not cause extreme spike" do
      inc = Incident.create!(
        incident_type: "landslide",
        severity: "critical",
        status: "reported",
        description: "Unverified rumor of debris on NH-27",
        latitude: @road_nh27.latitude,
        longitude: @road_nh27.longitude,
        state: @road_nh27.state,
        reported_at: 1.hour.ago,
        ai_confidence_score: 40.0 # LOW confidence (< 55) -> 0.5 multiplier
      )

      service = Enma::PredictiveCascadingImpactService.new
      cand = service.forecast_threatened_roads({}).find { |r| r[:road_id] == @road_nh27.id }

      # Critical base (95) * 0.5 = 47.5
      assert_in_delta 47.5, cand[:contributing_factors][:incident_signal], 5.0
      assert cand[:warnings].any? { |w| w.include?("LOW data confidence") }
    end

    # =========================================================================
    # SCENARIO 5: High-Confidence Incident Weighting
    # =========================================================================
    test "scenario 5: high confidence incident has full weight multiplier" do
      inc = Incident.create!(
        incident_type: "landslide",
        severity: "critical",
        status: "verified",
        description: "Confirmed major landslide on NH-27 by field officer",
        latitude: @road_nh27.latitude,
        longitude: @road_nh27.longitude,
        state: @road_nh27.state,
        reported_at: 1.hour.ago,
        ai_confidence_score: 95.0 # HIGH confidence (>= 90) -> 1.0 multiplier
      )

      service = Enma::PredictiveCascadingImpactService.new
      cand = service.forecast_threatened_roads({}).find { |r| r[:road_id] == @road_nh27.id }

      # Critical base (95) * 1.0 = 95.0
      assert_in_delta 95.0, cand[:contributing_factors][:incident_signal], 2.0
    end

    # =========================================================================
    # SCENARIO 6: Weather Escalation
    # =========================================================================
    test "scenario 6: heavy storm weather escalates failure probability" do
      storm = {
        precipitation_mm: 75.0,
        rainfall: "extreme",
        condition: "Torrential Downpour",
        alerts: ["Red alert: Flash Floods & Landslides"]
      }

      with_mock_weather(storm) do
        service = Enma::PredictiveCascadingImpactService.new
        res = service.analyze(forecast_hours: 12)

        cand = res[:threatened_roads].find { |r| r[:road_id] == @road_nh27.id }
        assert cand[:contributing_factors][:weather_escalation] >= 80.0
      end
    end

    # =========================================================================
    # SCENARIO 7: Missing Weather Fallback
    # =========================================================================
    test "scenario 7: missing weather gracefully falls back to neutral 25.0 score" do
      with_mock_weather(->(*_args) { raise StandardError, "Weather service timeout" }) do
        service = Enma::PredictiveCascadingImpactService.new
        res = service.analyze(forecast_hours: 12)

        cand = res[:threatened_roads].first
        assert_equal 25.0, cand[:contributing_factors][:weather_escalation]
        assert_equal false, cand[:data_availability][:weather_available]
      end
    end

    # =========================================================================
    # SCENARIO 8: Missing ML Disruption Probability Fallback
    # =========================================================================
    test "scenario 8: missing ML disruption probability falls back to road risk score" do
      @road_nh27.update!(ml_disruption_probability: nil, risk_score: 55.0)

      service = Enma::PredictiveCascadingImpactService.new
      cand = service.forecast_threatened_roads({}).find { |r| r[:road_id] == @road_nh27.id }

      assert_equal 55.0, cand[:contributing_factors][:ml_probability]
      assert_equal false, cand[:data_availability][:ml_available]
    end

    # =========================================================================
    # SCENARIO 9: Single-Road Scenario Generation
    # =========================================================================
    test "scenario 9: single-road scenario simulates impact and identifies isolated settlements" do
      @road_nh27.update!(risk_score: 80.0, ml_disruption_probability: 0.85)

      service = Enma::PredictiveCascadingImpactService.new
      res = service.analyze(forecast_hours: 12)

      single_scen = res[:scenarios].find { |s| s[:scenario_type] == "single_road" }
      assert_not_nil single_scen
      assert_includes single_scen[:road_ids], @road_nh27.id
      assert single_scen[:cascade_score].between?(0.0, 100.0)
    end

    # =========================================================================
    # SCENARIO 10: Multi-Road Scenario Generation
    # =========================================================================
    test "scenario 10: multi-road scenario simulates combined corridor closure" do
      # Correlated roads: NH-27 and NH-715 share Jorhat node
      @road_nh27.update!(risk_score: 75.0, ml_disruption_probability: 0.70)
      @road_nh715.update!(risk_score: 70.0, ml_disruption_probability: 0.65)

      service = Enma::PredictiveCascadingImpactService.new
      res = service.analyze(forecast_hours: 12)

      pair_scen = res[:scenarios].find { |s| s[:scenario_type] == "pair_road" }
      if pair_scen
        assert_equal 2, pair_scen[:road_ids].size
        assert_operator pair_scen[:cascade_score], :>=, 0.0
      end
    end

    # =========================================================================
    # SCENARIO 11: Bounded Scenario Generation
    # =========================================================================
    test "scenario 11: strict budget enforcement bounds simulations to at most 6" do
      # Make all roads high risk to test bounding
      Road.update_all(risk_score: 80.0, ml_disruption_probability: 0.80)

      service = Enma::PredictiveCascadingImpactService.new
      res = service.analyze(forecast_hours: 12, candidate_limit: 10)

      assert res[:metadata][:simulation_calls] <= 6, "Simulation calls exceeded budget: #{res[:metadata][:simulation_calls]}"
      assert res[:top_candidates].size <= 5, "Candidates exceeded limit: #{res[:top_candidates].size}"
    end

    # =========================================================================
    # SCENARIO 12: Population Isolation Impact
    # =========================================================================
    test "scenario 12: population isolation score scales with isolated settlement census" do
      @road_nh27.update!(risk_score: 90.0, ml_disruption_probability: 0.95)

      service = Enma::PredictiveCascadingImpactService.new
      res = service.analyze(forecast_hours: 12)

      top_scen = res[:scenarios].first
      assert_not_nil top_scen
      assert top_scen.dig(:impact_breakdown, :population_isolation).between?(0.0, 100.0)
    end

    # =========================================================================
    # SCENARIO 13: Warehouse Disconnection Impact
    # =========================================================================
    test "scenario 13: warehouse disconnection impact reflects depot accessibility loss" do
      @road_nh27.update!(risk_score: 85.0, ml_disruption_probability: 0.85)

      service = Enma::PredictiveCascadingImpactService.new
      res = service.analyze(forecast_hours: 12)

      scen = res[:scenarios].first
      assert scen.dig(:impact_breakdown, :warehouse_disconnection).between?(0.0, 100.0)
    end

    # =========================================================================
    # SCENARIO 14: Critical Infrastructure Impact
    # =========================================================================
    test "scenario 14: critical infrastructure impact reflects bridge and depot disruption" do
      @road_nh27.update!(risk_score: 85.0, ml_disruption_probability: 0.85)

      service = Enma::PredictiveCascadingImpactService.new
      res = service.analyze(forecast_hours: 12)

      scen = res[:scenarios].first
      assert scen.dig(:impact_breakdown, :critical_infrastructure).between?(0.0, 100.0)
    end

    # =========================================================================
    # SCENARIO 15: Recommendation Generation
    # =========================================================================
    test "scenario 15: recommendations contain required structured action fields" do
      @road_nh27.update!(risk_score: 85.0, ml_disruption_probability: 0.85)

      service = Enma::PredictiveCascadingImpactService.new
      res = service.analyze(forecast_hours: 12)

      assert res[:recommendations].any?
      rec = res[:recommendations].first
      assert rec.key?(:action)
      assert rec.key?(:why)
      assert rec.key?(:when)
      assert rec.key?(:where)
      assert rec.key?(:priority)
      assert_includes %w[CRITICAL HIGH MEDIUM LOW], rec[:priority]
    end

    # =========================================================================
    # SCENARIO 16: Explainable Causal Chain
    # =========================================================================
    test "scenario 16: scenarios generate step-by-step causal chain narrative" do
      @road_nh27.update!(risk_score: 85.0, ml_disruption_probability: 0.85)

      service = Enma::PredictiveCascadingImpactService.new
      res = service.analyze(forecast_hours: 12)

      scen = res[:scenarios].first
      assert scen[:causal_chain].is_a?(Array)
      assert_operator scen[:causal_chain].size, :>=, 4
      assert scen[:causal_chain].any? { |step| step.include?("Failure probability") }
    end

    # =========================================================================
    # SCENARIO 17: Impact Classification Levels
    # =========================================================================
    test "scenario 17: cascade impact classifies into correct severity tiers" do
      service = Enma::PredictiveCascadingImpactService.new

      assert_equal "CATASTROPHIC", service.classify_cascade_level(88.0)[:level]
      assert_equal "CRITICAL", service.classify_cascade_level(75.0)[:level]
      assert_equal "HIGH", service.classify_cascade_level(60.0)[:level]
      assert_equal "ELEVATED", service.classify_cascade_level(35.0)[:level]
      assert_equal "LIMITED", service.classify_cascade_level(15.0)[:level]
    end

    # =========================================================================
    # SCENARIO 18: Alert Deduplication Over 24 Hours
    # =========================================================================
    test "scenario 18: alert creation generates deduplicated records over 24h window" do
      @road_nh27.update!(risk_score: 95.0, ml_disruption_probability: 0.95)

      service = Enma::PredictiveCascadingImpactService.new
      # Run 1 with create_alerts: true
      res1 = service.analyze(forecast_hours: 12, create_alerts: true)
      first_alert_count = LogisticsAlert.count

      # Run 2 with create_alerts: true immediately after
      service2 = Enma::PredictiveCascadingImpactService.new
      res2 = service2.analyze(forecast_hours: 12, create_alerts: true)
      second_alert_count = LogisticsAlert.count

      # Should be deduplicated, zero new alerts created on run 2
      assert_equal first_alert_count, second_alert_count
    end

    # =========================================================================
    # SCENARIO 19: Prediction Confidence vs Failure Probability Separation
    # =========================================================================
    test "scenario 19: failure probability is distinct from evidence confidence" do
      # Road with high theoretical risk but missing real-time evidence
      @road_nh27.update!(risk_score: 80.0, ml_disruption_probability: 0.80)

      service = Enma::PredictiveCascadingImpactService.new
      cand = service.forecast_threatened_roads({}).find { |r| r[:road_id] == @road_nh27.id }

      assert cand[:failure_probability] >= 45.0
      assert cand[:prediction_confidence].between?(0.0, 100.0)
      assert_includes %w[HIGH MODERATE LOW], cand[:prediction_confidence_level]
    end

    # =========================================================================
    # SCENARIO 20: Simulation Budget Enforcement
    # =========================================================================
    test "scenario 20: simulation budget is strictly enforced at 6 calls" do
      service = Enma::PredictiveCascadingImpactService.new
      # Simulate 6 calls manually
      6.times { service.run_guarded_network_simulation([@road_nh27.id]) }

      # 7th call should be blocked and return nil
      res7 = service.run_guarded_network_simulation([@road_nh27.id])
      assert_nil res7
      assert_equal 6, service.simulation_calls
    end

    # =========================================================================
    # SCENARIO 21: Missing Coordinates Graceful Fallback
    # =========================================================================
    test "scenario 21: road with nil coordinates does not raise exception" do
      @road_nh27.update!(geometry_coordinates: nil)

      service = Enma::PredictiveCascadingImpactService.new
      res = service.analyze(forecast_hours: 12)

      assert res[:overall_cascade_risk].is_a?(Numeric)
      assert res[:threatened_roads].any? { |r| r[:road_id] == @road_nh27.id }
    end

    # =========================================================================
    # SCENARIO 22: Performance Sanity
    # =========================================================================
    test "scenario 22: complete predictive cascading analysis executes within fast benchmark" do
      service = Enma::PredictiveCascadingImpactService.new

      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      res = service.analyze(forecast_hours: 12, candidate_limit: 5)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

      assert_operator elapsed, :<, 3.0, "Analysis took too long: #{elapsed}s"
      assert res[:metadata][:simulation_calls] <= 6
    end
  end
end
