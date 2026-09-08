# frozen_string_literal: true

require "test_helper"

module ResQWay
  class UnifiedEmergencyCommandServiceTest < ActiveSupport::TestCase
    def setup
      LogisticsAlert.delete_all
      Incident.delete_all
      Road.delete_all
      Warehouse.delete_all
      Location.delete_all

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

      @wh_guwahati = Warehouse.create!(
        name: "Guwahati Central Depot",
        location: @guwahati,
        operational_status: "OPERATIONAL",
        capacity: 3000,
        utilized_capacity: 1200,
        latitude: 26.1445,
        longitude: 91.7362
      )

      @wh_kohima = Warehouse.create!(
        name: "Kohima Staging Depot",
        location: @kohima,
        operational_status: "OPERATIONAL",
        capacity: 1500,
        utilized_capacity: 600,
        latitude: 25.6701,
        longitude: 94.1077
      )

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

      @service = ResQWay::UnifiedEmergencyCommandService.new(
        locations: @locations,
        warehouses: @warehouses,
        roads: @roads
      )
    end

    # =========================================================================
    # CATEGORY 1: Historical Decision Context Retrieval
    # =========================================================================
    test "category 1: retrieves historical commander decisions accurately from recorded alerts" do
      LogisticsAlert.create!(
        alert_type: "commander_feedback_recorded",
        severity: "info",
        title: "Decision: APPROVED",
        message: "Historical approval for NH-02 route",
        status: "acknowledged",
        metadata_json: {
          decision: "APPROVED",
          scenario_fingerprint: "SCENARIO-ALPHA",
          recommendation_fingerprint: "REC-ALPHA"
        }
      )

      result = @service.analyze(forecast_hours: 12)
      hist = result[:historical_context]

      assert_equal 1, hist[:total_recorded_decisions]
      assert_equal 1, hist[:decision_breakdown]["APPROVED"]
      assert_includes hist.keys, :similar_previous_scenarios
      assert_includes hist.keys, :disclaimer
    end

    # =========================================================================
    # CATEGORY 2: Historical Context Does Not Override Current Plan
    # =========================================================================
    test "category 2: historical context is labeled advisory and does not override current plan" do
      # Create historical rejection of a strategy
      LogisticsAlert.create!(
        alert_type: "commander_feedback_recorded",
        severity: "warning",
        title: "Decision: REJECTED",
        message: "Commander rejected previous route",
        status: "acknowledged",
        metadata_json: {
          decision: "REJECTED",
          scenario_fingerprint: "DIVERGENT-FP",
          recommendation_fingerprint: "DIVERGENT-REC"
        }
      )

      result = @service.analyze(forecast_hours: 12)

      assert_equal "ACTIVE", result[:status]
      assert_includes result[:historical_context][:disclaimer], "advisory decision support only"
      assert result[:command_state][:human_control_required]
      assert_not result[:command_state][:autonomous_execution]
      assert_equal "AWAITING_HUMAN_COMMAND_APPROVAL", result[:command_state][:phase]
    end

    # =========================================================================
    # CATEGORY 3: Plan Assumption Generation
    # =========================================================================
    test "category 3: generates structured plan assumptions across critical dependency categories" do
      result = @service.analyze(forecast_hours: 12)
      assumptions = result[:plan_assumptions]

      assert assumptions.is_a?(Array)
      assert assumptions.size >= 3

      types = assumptions.map { |a| a[:dependency_type] }.uniq
      assert_includes types, "ROAD_ACCESSIBILITY"
      assert_includes types, "WAREHOUSE_CAPACITY"

      assumptions.each do |a|
        assert a.key?(:id)
        assert a.key?(:description)
        assert a.key?(:confidence)
        assert %w[VALID DEGRADED AT_RISK INVALIDATED].include?(a[:status])
        assert %w[LOW MEDIUM HIGH CRITICAL].include?(a[:sensitivity])
      end
    end

    # =========================================================================
    # CATEGORY 4: Critical Assumption Invalidation Triggers Drift / Reoptimization
    # =========================================================================
    test "category 4: invalidation of critical road assumption triggers plan drift and reoptimization" do
      # Baseline snapshot when road is accessible
      baseline = @service.analyze(forecast_hours: 12)
      baseline_snapshot = baseline[:situation_snapshot]

      # Now simulate catastrophic road failure on the direct corridor
      @road_direct.update!(status: "blocked", risk_score: 95.0, ml_disruption_probability: 0.95)

      subsequent_service = ResQWay::UnifiedEmergencyCommandService.new(
        locations: @locations,
        warehouses: @warehouses,
        roads: [@road_arterial, @road_direct, @road_bypass, @road_kang_imphal],
        previous_snapshot: baseline_snapshot
      )

      result = subsequent_service.analyze(forecast_hours: 12)

      assert result[:plan_drift][:detected]
      assert result[:plan_drift][:reoptimization_required]
      assert_includes %w[HIGH CRITICAL], result[:plan_drift][:severity]
      assert result[:reoptimization][:reoptimization_performed]
      assert_not_nil result[:reoptimization][:revised_strategy]
    end

    # =========================================================================
    # CATEGORY 5: Assumption Health Scoring
    # =========================================================================
    test "category 5: calculates assumption health score accurately reflecting degraded state" do
      result = @service.analyze(forecast_hours: 12)
      initial_health = result[:assumption_health_score]
      assert initial_health >= 0.0 && initial_health <= 100.0

      # Block direct corridor and verify health score decreases
      @road_direct.update!(status: "blocked", risk_score: 98.0)
      degraded_service = ResQWay::UnifiedEmergencyCommandService.new(
        locations: @locations,
        warehouses: @warehouses,
        roads: [@road_arterial, @road_direct, @road_bypass, @road_kang_imphal]
      )
      degraded_result = degraded_service.analyze(forecast_hours: 12)

      assert degraded_result[:assumption_health_score] < initial_health
    end

    # =========================================================================
    # CATEGORY 6: Graceful Degradation: Weather Service Unavailable
    # =========================================================================
    test "category 6: degrades gracefully when weather service is unavailable" do
      dry_locations = @locations.map { |l| l.dup.tap { |loc| loc.rainfall_level = nil } }
      service = ResQWay::UnifiedEmergencyCommandService.new(
        locations: dry_locations,
        warehouses: @warehouses,
        roads: @roads
      )
      result = service.analyze(forecast_hours: 12)

      assert_equal "ACTIVE", result[:status]
      assert result.key?(:data_reliability)
      assert_equal "UNAVAILABLE", result[:data_reliability][:sources][:weather][:status]
      assert result[:data_reliability][:degraded_mode]
    end

    # =========================================================================
    # CATEGORY 7: Graceful Degradation: Prediction Service Unavailable
    # =========================================================================
    test "category 7: degrades gracefully with heuristic fallback when predictive engine errors" do
      failing_predictive_service = Object.new
      def failing_predictive_service.analyze(*_args)
        raise StandardError, "ML Service RPC Timeout"
      end

      service = ResQWay::UnifiedEmergencyCommandService.new(
        locations: @locations,
        warehouses: @warehouses,
        roads: @roads,
        predictive_service: failing_predictive_service
      )

      result = service.analyze(forecast_hours: 12)

      assert_equal "ACTIVE", result[:status]
      assert_not result[:data_reliability][:sources][:predictive_intelligence][:available]
      assert result[:data_reliability][:degraded_mode]
    end

    # =========================================================================
    # CATEGORY 8: Graceful Degradation: Partial Warehouse Data
    # =========================================================================
    test "category 8: handles partial or zero warehouse availability without arithmetic errors" do
      @wh_guwahati.update!(operational_status: "INACCESSIBLE", capacity: 0)
      @wh_kohima.update!(operational_status: "INACCESSIBLE", capacity: 0)

      result = @service.analyze(forecast_hours: 12)

      assert_equal "ACTIVE", result[:status]
      assert_equal 0, result[:situation_snapshot][:available_warehouses]
      assert result.key?(:response_optimization)
    end

    # =========================================================================
    # CATEGORY 9: Operational Degraded Intelligence Mode Flag & Warning
    # =========================================================================
    test "category 9: sets operational degraded mode flag and generates clear warnings when feeds fail" do
      failing_predictive = Object.new
      def failing_predictive.analyze(*_args)
        raise StandardError, "Service Unavailable"
      end

      service = ResQWay::UnifiedEmergencyCommandService.new(
        locations: @locations,
        warehouses: @warehouses,
        roads: @roads,
        predictive_service: failing_predictive
      )

      result = service.analyze(forecast_hours: 12)

      assert result[:data_reliability][:degraded_mode]
      assert result[:data_reliability][:warnings].any?
      assert_includes result[:data_reliability][:warnings].join, "Degraded Intelligence Mode"
    end

    # =========================================================================
    # CATEGORY 10: Low Uncertainty Decision Behavior
    # =========================================================================
    test "category 10: produces low uncertainty level and tight confidence intervals under nominal conditions" do
      result = @service.analyze(forecast_hours: 12)
      unc = result[:uncertainty_analysis]

      assert_includes %w[LOW MODERATE], unc[:uncertainty_level]
      assert_equal 2, unc[:confidence_interval].size
      assert unc[:confidence_interval][0] <= unc[:confidence_interval][1]
    end

    # =========================================================================
    # CATEGORY 11: High Uncertainty Decision Behavior
    # =========================================================================
    test "category 11: identifies high uncertainty when data reliability drops significantly" do
      failing_predictive = Object.new
      def failing_predictive.analyze(*_args)
        raise StandardError, "Prediction Failure"
      end

      service = ResQWay::UnifiedEmergencyCommandService.new(
        locations: @locations,
        warehouses: @warehouses,
        roads: @roads,
        predictive_service: failing_predictive
      )

      result = service.analyze(forecast_hours: 12)
      unc = result[:uncertainty_analysis]

      assert unc[:uncertainty_score] > 20.0
      assert unc[:key_uncertainties].any?
    end

    # =========================================================================
    # CATEGORY 12: Critical Uncertainty Avoids Irreversible Commitment
    # =========================================================================
    test "category 12: critical uncertainty caps commitment level below level 4 recommended action" do
      failing_predictive = Object.new
      def failing_predictive.analyze(*_args)
        raise StandardError, "Prediction Failure"
      end

      failing_response = Object.new
      def failing_response.analyze(*_args)
        raise StandardError, "Response Failure"
      end

      service = ResQWay::UnifiedEmergencyCommandService.new(
        locations: @locations,
        warehouses: @warehouses,
        roads: @roads,
        predictive_service: failing_predictive,
        response_service: failing_response
      )

      result = service.analyze(forecast_hours: 12)
      commitment = result[:commitment_level][:level]

      assert_not_equal "LEVEL_4_RECOMMENDED_ACTION", commitment
      assert_includes %w[LEVEL_0_MONITOR LEVEL_1_VERIFY LEVEL_2_PREPARE LEVEL_3_CONDITIONAL_ACTION], commitment
    end

    # =========================================================================
    # CATEGORY 13: Verification-First Trigger on High Impact / Low Confidence
    # =========================================================================
    test "category 13: triggers verification recommendation when high impact corridor has low confidence" do
      # Create an incident with low confidence on direct road
      Incident.create!(
        description: "Unverified Rockfall Report",
        incident_type: "landslide",
        severity: "critical",
        status: "reported",
        latitude: 25.6701,
        longitude: 94.1077,
        reported_at: Time.current,
        ai_confidence_score: 25.0
      )

      result = @service.analyze(forecast_hours: 12)
      actions = result[:verification_recommendations]

      assert actions.any?
      assert actions.any? { |a| a[:urgency] == "IMMEDIATE" || a[:target_type] == "ROAD_CORRIDOR" }
    end

    # =========================================================================
    # CATEGORY 14: UAV Verification Recommendation
    # =========================================================================
    test "category 14: recommends UAV reconnaissance for inaccessible or high-risk remote mountain passes" do
      @road_direct.update!(risk_score: 90.0, status: "blocked")

      result = @service.analyze(forecast_hours: 12)
      actions = result[:verification_recommendations]

      recon_modes = actions.map { |a| a[:suggested_mode] }
      assert(recon_modes.include?("UAV_RECON") || recon_modes.include?("FIELD_RECON"))
    end

    # =========================================================================
    # CATEGORY 15: Conflicting Signal Verification
    # =========================================================================
    test "category 15: generates verification action when conflicting signals are detected" do
      # Road marked accessible in DB, but severe incident posted
      @road_direct.update!(status: "accessible", risk_score: 30.0)
      Incident.create!(
        description: "Report of Total Bridge Collapse",
        incident_type: "bridge_damage",
        severity: "critical",
        status: "reported",
        latitude: 25.6701,
        longitude: 94.1077,
        reported_at: Time.current,
        ai_confidence_score: 40.0
      )

      result = @service.analyze(forecast_hours: 12)
      recs = result[:verification_recommendations]

      assert recs.any?
      assert recs.all? { |r| r[:information_gain_score] >= 0.0 }
    end

    # =========================================================================
    # CATEGORY 16: Commander Attention Prioritization
    # =========================================================================
    test "category 16: commander attention prioritized with standardized action verbs" do
      result = @service.analyze(forecast_hours: 12)
      attention = result[:commander_attention]

      assert attention.is_a?(Array)
      assert attention.all? { |item| %w[ACT_NOW DECIDE_NOW VERIFY_NOW PREPARE MONITOR].include?(item[:action]) }
      assert attention.all? { |item| item.key?(:title) && item.key?(:urgency) && item.key?(:reason) }
    end

    # =========================================================================
    # CATEGORY 17: Top 3 Attention Items Limit
    # =========================================================================
    test "category 17: strictly enforces a maximum of 3 commander attention items" do
      # Cause multiple simultaneous triggers
      @road_direct.update!(status: "blocked", risk_score: 95.0)
      @road_bypass.update!(status: "high_risk", risk_score: 75.0)
      Incident.create!(
        description: "Multi-point landslide",
        incident_type: "landslide",
        severity: "critical",
        status: "reported",
        latitude: 25.1500,
        longitude: 93.9800,
        reported_at: Time.current,
        ai_confidence_score: 45.0
      )

      result = @service.analyze(forecast_hours: 12)
      attention = result[:commander_attention]

      assert attention.size <= 3
      assert attention.size >= 1
    end

    # =========================================================================
    # CATEGORY 18: No-Action Baseline Generation
    # =========================================================================
    test "category 18: generates counterfactual no-action baseline with comparative consequence postures" do
      result = @service.analyze(forecast_hours: 12)
      baseline = result[:no_action_baseline]

      assert baseline.key?(:narrative)
      assert baseline.key?(:postures)
      assert baseline[:postures].is_a?(Array)

      posture_names = baseline[:postures].map { |p| p[:posture] }
      assert_includes posture_names, "NO_ACTION"
      assert_includes posture_names, "RECOMMENDED_OPTIMIZATION"
    end

    # =========================================================================
    # CATEGORY 19: Minimal vs Recommended Plan Comparison
    # =========================================================================
    test "category 19: compares minimal dispatch vs recommended plan showing consequence trade-offs" do
      result = @service.analyze(forecast_hours: 12)
      postures = result[:no_action_baseline][:postures]

      no_action = postures.find { |p| p[:posture] == "NO_ACTION" }
      recommended = postures.find { |p| p[:posture] == "RECOMMENDED_OPTIMIZATION" }

      assert_not_nil no_action
      assert_not_nil recommended
      assert recommended[:population_served_pct] >= no_action[:population_served_pct]
    end

    # =========================================================================
    # CATEGORY 20: Decision Trace Completeness
    # =========================================================================
    test "category 20: builds sequential explainable decision trace across all 6 stages" do
      result = @service.analyze(forecast_hours: 12)
      trace = result[:decision_trace]

      assert trace.is_a?(Array)
      stages = trace.map { |t| t[:stage] }

      assert_includes stages, "SIGNAL"
      assert_includes stages, "SITUATION"
      assert_includes stages, "PREDICTION"
      assert_includes stages, "NETWORK"
      assert_includes stages, "OPTIMIZATION"
      assert_includes stages, "COMMAND_DECISION"

      trace.each do |step|
        assert step.key?(:title)
        assert step.key?(:summary)
        assert step.key?(:status)
      end
    end

    # =========================================================================
    # CATEGORY 21: Commitment Level Classification
    # =========================================================================
    test "category 21: maps operational commitment levels from LEVEL 0 to LEVEL 4 accurately" do
      result = @service.analyze(forecast_hours: 12)
      commitment = result[:commitment_level]

      assert commitment.key?(:level)
      assert commitment.key?(:label)
      assert %w[LEVEL_0_MONITOR LEVEL_1_VERIFY LEVEL_2_PREPARE LEVEL_3_CONDITIONAL_ACTION LEVEL_4_RECOMMENDED_ACTION].include?(commitment[:level])
    end

    # =========================================================================
    # CATEGORY 22: High Confidence Emergency Recommendation
    # =========================================================================
    test "category 22: high confidence severe threat escalates commitment level appropriately" do
      # Direct corridor is at severe risk with high probability
      @road_direct.update!(risk_score: 90.0, ml_disruption_probability: 0.85)

      result = @service.analyze(forecast_hours: 12)
      commitment = result[:commitment_level][:level]

      assert_includes %w[LEVEL_3_CONDITIONAL_ACTION LEVEL_4_RECOMMENDED_ACTION], commitment
    end

    # =========================================================================
    # CATEGORY 23: Low Confidence High Impact Verification Recommendation
    # =========================================================================
    test "category 23: low confidence high impact scenario produces verification-first focus" do
      failing_predictive = Object.new
      def failing_predictive.analyze(*_args)
        raise StandardError, "Prediction Failure"
      end

      service = ResQWay::UnifiedEmergencyCommandService.new(
        locations: @locations,
        warehouses: @warehouses,
        roads: @roads,
        predictive_service: failing_predictive
      )

      result = service.analyze(forecast_hours: 12)
      commitment = result[:commitment_level][:level]

      # Low confidence should keep commitment bounded to verify/prepare/conditional
      assert_not_equal "LEVEL_4_RECOMMENDED_ACTION", commitment
    end

    # =========================================================================
    # CATEGORY 24: Scenario Comparison Maximum 3
    # =========================================================================
    test "category 24: limits scenario comparison strictly to a maximum of 3 scenarios" do
      result = @service.analyze(forecast_hours: 12)
      scenarios = result[:scenario_comparison]

      assert scenarios.is_a?(Array)
      assert scenarios.size <= 3
      assert scenarios.size >= 1
      scenarios.each do |sc|
        assert sc.key?(:scenario_name)
        assert sc.key?(:threat_level)
        assert sc.key?(:resilience_score)
      end
    end

    # =========================================================================
    # CATEGORY 25: Scenario Deterministic Consistency
    # =========================================================================
    test "category 25: produces deterministic outputs for identical inputs" do
      res1 = @service.analyze(forecast_hours: 12)
      res2 = @service.analyze(forecast_hours: 12)

      assert_equal res1[:situation_snapshot][:scenario_fingerprint], res2[:situation_snapshot][:scenario_fingerprint]
      assert_equal res1[:commitment_level][:level], res2[:commitment_level][:level]
      assert_equal res1[:commander_attention].size, res2[:commander_attention].size
    end

    # =========================================================================
    # CATEGORY 26: Graceful Dependency Failure
    # =========================================================================
    test "category 26: handles empty database dependencies gracefully without nil exceptions" do
      empty_service = ResQWay::UnifiedEmergencyCommandService.new(
        locations: [],
        warehouses: [],
        roads: []
      )

      result = empty_service.analyze(forecast_hours: 12)

      assert_equal "ACTIVE", result[:status]
      assert_equal "MONITORING", result[:command_state][:phase]
      assert result[:command_state][:human_control_required]
      assert_not result[:command_state][:autonomous_execution]
      assert_equal 100.0, result[:assumption_health_score]
    end

    # =========================================================================
    # CATEGORY 27: No Mutation of Source Data
    # =========================================================================
    test "category 27: does not mutate source road, warehouse, or location records" do
      road_status_before = @road_direct.status
      wh_cap_before = @wh_guwahati.capacity
      loc_pop_before = @imphal.population

      @service.analyze(forecast_hours: 12)

      assert_equal road_status_before, @road_direct.reload.status
      assert_equal wh_cap_before, @wh_guwahati.reload.capacity
      assert_equal loc_pop_before, @imphal.reload.population
    end

    # =========================================================================
    # CATEGORY 28: Performance Under 2 Seconds
    # =========================================================================
    test "category 28: full command cycle executes strictly under 2.0 seconds" do
      result = @service.analyze(forecast_hours: 12)
      execution_ms = result[:instrumentation][:execution_time_ms]

      assert execution_ms < 2000.0, "Expected execution time < 2000ms, was #{execution_ms}ms"
    end
  end
end
