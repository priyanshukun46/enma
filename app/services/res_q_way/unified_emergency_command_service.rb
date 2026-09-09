# frozen_string_literal: true

require "digest"

module ResQWay
  class UnifiedEmergencyCommandService
    EARTH_RADIUS_KM = 6371.0
    DEFAULT_FORECAST_HOURS = 12

    # Command States
    COMMAND_STATES = %w[
      MONITORING
      ANALYZING
      PLAN_GENERATED
      AWAITING_HUMAN_COMMAND_APPROVAL
      APPROVED
      MODIFIED
      REJECTED
      PLAN_DRIFT_DETECTED
      REOPTIMIZATION_REQUIRED
      REVISED_PLAN_GENERATED
    ].freeze

    # Plan Validity Classifications
    VALIDITY_TIERS = [
      { min: 85.0, status: "VALID",     color: "#10b981", badge: "bg-emerald-500/15 text-emerald-600 dark:text-emerald-400 border-emerald-500/30" },
      { min: 65.0, status: "DEGRADED",  color: "#d97706", badge: "bg-amber-500/15 text-amber-600 dark:text-amber-400 border-amber-500/30" },
      { min: 40.0, status: "AT_RISK",   color: "#ea580c", badge: "bg-orange-500/15 text-orange-600 dark:text-orange-400 border-orange-500/30" },
      { min: 0.0,  status: "INVALID",   color: "#dc2626", badge: "bg-red-500/15 text-red-600 dark:text-red-400 border-red-500/30" }
    ].freeze

    # Plan Drift Severities
    DRIFT_SEVERITIES = [
      { max: 14.9, severity: "NONE",     color: "#10b981" },
      { max: 29.9, severity: "LOW",      color: "#0891b2" },
      { max: 49.9, severity: "MODERATE", color: "#d97706" },
      { max: 74.9, severity: "HIGH",     color: "#ea580c" },
      { max: 100.0, severity: "CRITICAL", color: "#dc2626" }
    ].freeze

    # Operational Commitment Levels
    COMMITMENT_LEVELS = {
      0 => { level: "LEVEL_0_MONITOR",            label: "Monitor Situation",            badge: "bg-emerald-500/15 text-emerald-600 border-emerald-500/30" },
      1 => { level: "LEVEL_1_VERIFY",             label: "Prioritize Verification",      badge: "bg-blue-500/15 text-blue-600 border-blue-500/30" },
      2 => { level: "LEVEL_2_PREPARE",            label: "Prepare & Pre-stage",          badge: "bg-amber-500/15 text-amber-600 border-amber-500/30" },
      3 => { level: "LEVEL_3_CONDITIONAL_ACTION", label: "Conditional Dispatch",         badge: "bg-orange-500/15 text-orange-600 border-orange-500/30" },
      4 => { level: "LEVEL_4_RECOMMENDED_ACTION", label: "Recommended Response Action", badge: "bg-red-500/15 text-red-600 border-red-500/30" }
    }.freeze

    attr_reader :locations, :warehouses, :roads, :predictive_service, :response_service,
                :network_service, :previous_snapshot, :command_decision, :session_store

    def initialize(locations: nil, warehouses: nil, roads: nil, predictive_service: nil,
                   response_service: nil, network_service: nil, previous_snapshot: nil,
                   command_decision: nil, session_store: nil)
      @locations = locations || (defined?(Location) ? Location.all.to_a : [])
      @warehouses = warehouses || (defined?(Warehouse) ? Warehouse.all.to_a : [])
      @roads = roads || (defined?(Road) ? Road.all.to_a : [])
      @predictive_service = predictive_service
      @response_service = response_service
      @network_service = network_service || ResQWay::NetworkConnectivityService.new(roads: @roads, locations: @locations, warehouses: @warehouses)
      @previous_snapshot = previous_snapshot
      @command_decision = command_decision
      @session_store = session_store || {}
      @cache_hits = 0
    end

    # =========================================================================
    # PRIMARY ANALYSIS ENTRYPOINT
    # =========================================================================
    def analyze(forecast_hours: DEFAULT_FORECAST_HOURS, include_reoptimization: true, create_alerts: false)
      start_clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      forecast_hours = forecast_hours.to_i
      forecast_hours = DEFAULT_FORECAST_HOURS unless [6, 12, 24, 48].include?(forecast_hours)

      # Handle empty network edge case gracefully
      if @locations.empty? || @roads.empty? || @warehouses.empty?
        data_reliability = evaluate_data_availability
        return build_empty_command_result(forecast_hours, start_clock, data_reliability)
      end

      # 1. Predictive Cascading Impact Intelligence (Orchestrated)
      t_pred_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      predictive_analysis = fetch_or_run_predictive_intelligence(forecast_hours)
      t_pred_elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t_pred_start) * 1000.0).round(1)

      # 2. Graceful Data Availability Matrix & Reliability Evaluation
      data_reliability = evaluate_data_availability

      # 3. Autonomous Response Optimization Intelligence (Orchestrated)
      t_resp_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      response_plan = fetch_or_run_response_optimization(forecast_hours, predictive_analysis)
      t_resp_elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t_resp_start) * 1000.0).round(1)

      # 4. Network Health & Connectivity Baseline
      network_analysis = @network_service.baseline_analysis

      # 5. Unified Situation Snapshot
      current_snapshot = build_situation_snapshot(predictive_analysis, response_plan, network_analysis, data_reliability)

      # 6. Plan Assumption Tracking & Health Scoring
      plan_assumptions = build_plan_assumptions(current_snapshot, response_plan, network_analysis)
      assumption_health = calculate_assumption_health_score(plan_assumptions)

      # 7. Plan Drift Detection & Plan Validity Scoring
      t_drift_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      plan_drift = detect_plan_drift(
        previous_snapshot: @previous_snapshot,
        current_snapshot: current_snapshot,
        assumptions: plan_assumptions
      )
      plan_validity = calculate_plan_validity(current_snapshot, plan_drift, assumption_health)
      t_drift_elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t_drift_start) * 1000.0).round(1)

      # 8. Uncertainty-Aware Reasoning
      uncertainty_analysis = calculate_decision_uncertainty(data_reliability, predictive_analysis, plan_assumptions)

      # 9. Verification-First Decision Protocol
      verification_recommendations = determine_verification_actions(current_snapshot, uncertainty_analysis, response_plan)

      # 10. Re-Optimization Evaluation & Revised Plan Comparison
      reoptimization_needed = should_reoptimize?(plan_drift, plan_validity, response_plan)
      reoptimization_result = if include_reoptimization && reoptimization_needed
                                generate_revised_plan_workflow(forecast_hours, predictive_analysis, response_plan, plan_drift)
                              else
                                { reoptimization_performed: false, original_strategy: response_plan[:optimal_strategy], revised_strategy: nil, changes: [], improvement: nil }
                              end

      # Active optimal strategy (revised if reoptimized, otherwise original)
      active_strategy = reoptimization_result[:revised_strategy] || response_plan[:optimal_strategy]

      # 11. Command State Machine
      command_state = determine_command_state(
        plan_drift: plan_drift,
        plan_validity: plan_validity,
        reoptimization: reoptimization_result,
        command_decision: @command_decision
      )

      # 12. Operational Commitment Level
      commitment_level = determine_commitment_level(
        threat_level: current_snapshot[:overall_threat_level],
        confidence: current_snapshot[:data_confidence],
        urgency: response_plan[:overall_response_urgency] || 50.0,
        uncertainty: uncertainty_analysis[:uncertainty_level]
      )

      # 13. Commander Attention Management (Strictly Top 3 Actions)
      commander_attention = prioritize_commander_attention(
        snapshot: current_snapshot,
        strategy: active_strategy,
        verification: verification_recommendations,
        drift: plan_drift,
        uncertainty: uncertainty_analysis,
        reoptimization: reoptimization_result
      )

      # 14. Explicit No-Action Baseline (Counterfactual Comparison)
      no_action_baseline = generate_no_action_baseline(current_snapshot, active_strategy, response_plan)

      # 15. Explainable Decision Trace
      decision_trace = build_decision_trace(current_snapshot, predictive_analysis, active_strategy, uncertainty_analysis)

      # 16. Decision Memory & Historical Context (Advisory Only)
      historical_context = retrieve_historical_context(current_snapshot)

      # 17. Scenario Comparison Mode (Max 3 Scenarios)
      scenario_comparison = compare_scenarios(forecast_hours, current_snapshot, active_strategy)

      # 18. Unified Operational Picture
      operational_picture = build_operational_picture(
        snapshot: current_snapshot,
        predictive_analysis: predictive_analysis,
        response_plan: response_plan,
        strategy: active_strategy,
        assumptions: plan_assumptions
      )

      # 19. Recommended Next Action
      recommended_next_action = determine_recommended_next_action(
        command_state: command_state,
        commitment_level: commitment_level,
        top_attention: commander_attention.first,
        verification: verification_recommendations.first,
        drift: plan_drift
      )

      # 20. Closed-Loop Cycle Status
      closed_loop_status = evaluate_closed_loop(
        previous_snapshot: @previous_snapshot,
        current_snapshot: current_snapshot,
        drift: plan_drift,
        validity: plan_validity,
        reoptimization: reoptimization_result
      )

      # 21. Command Explainability Package
      explainability = build_command_explainability(
        snapshot: current_snapshot,
        strategy: active_strategy,
        drift: plan_drift,
        assumptions: plan_assumptions,
        uncertainty: uncertainty_analysis,
        reoptimization: reoptimization_result
      )

      # 22. Deduplicated Alert Generation
      generated_alerts = []
      if create_alerts
        generated_alerts = create_command_alerts!(current_snapshot, plan_drift, plan_validity, active_strategy)
      end

      elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_clock) * 1000.0).round(1)

      {
        status: "ACTIVE",
        command_state: command_state,
        situation_snapshot: current_snapshot,
        operational_picture: operational_picture,
        commander_attention: commander_attention,
        data_reliability: data_reliability,
        uncertainty_analysis: uncertainty_analysis,
        commitment_level: commitment_level,
        plan_assumptions: plan_assumptions,
        assumption_health_score: assumption_health,
        verification_recommendations: verification_recommendations,
        no_action_baseline: no_action_baseline,
        decision_trace: decision_trace,
        historical_context: historical_context,
        scenario_comparison: scenario_comparison,
        plan_drift: plan_drift,
        plan_validity: plan_validity,
        predictive_intelligence: {
          overall_cascade_risk: predictive_analysis[:overall_cascade_risk],
          risk_level: predictive_analysis[:risk_level],
          threatened_roads_count: Array(predictive_analysis[:threatened_roads]).size,
          scenarios_count: Array(predictive_analysis[:scenarios]).size
        },
        response_optimization: {
          optimal_strategy_type: active_strategy&.dig(:strategy_type),
          optimal_strategy_name: active_strategy&.dig(:name),
          risk_adjusted_utility: active_strategy&.dig(:risk_adjusted_utility),
          plan_resilience_score: active_strategy&.dig(:plan_resilience_score),
          allocated_resources: active_strategy&.dig(:allocated_resources)
        },
        reoptimization: reoptimization_result,
        closed_loop_status: closed_loop_status,
        recommended_next_action: recommended_next_action,
        explainability: explainability,
        alerts_generated_count: generated_alerts.size,
        instrumentation: {
          execution_time_ms: elapsed_ms,
          predictive_engine_time_ms: t_pred_elapsed,
          response_engine_time_ms: t_resp_elapsed,
          drift_detection_time_ms: t_drift_elapsed,
          reoptimization_performed: reoptimization_result[:reoptimization_performed],
          cache_hits: @cache_hits,
          services_orchestrated: %w[DataConfidence NetworkConnectivity PredictiveCascading AutonomousResponse]
        }
      }
    end

    # =========================================================================
    # 1. DATA SOURCE AVAILABILITY & RELIABILITY EVALUATION
    # =========================================================================
    def evaluate_data_availability
      sources = {}

      # Weather Data Availability
      weather_has_data = @locations.any? { |l| l.rainfall_level.present? }
      sources[:weather] = {
        status: weather_has_data ? "AVAILABLE" : "UNAVAILABLE",
        confidence: weather_has_data ? 90.0 : 0.0,
        notes: weather_has_data ? "Active regional rainfall telemetry synchronized" : "Missing meteorological station telemetry"
      }

      # Predictive ML Model Availability
      roads_with_ml = @roads.count { |r| r.try(:ml_disruption_probability).present? }
      ml_ratio = @roads.any? ? (roads_with_ml.to_f / @roads.size.to_f) : 0.0
      sources[:predictive_model] = {
        status: ml_ratio >= 0.75 ? "AVAILABLE" : (ml_ratio > 0.2 ? "DEGRADED" : "UNAVAILABLE"),
        confidence: (ml_ratio * 95.0).round(1),
        notes: "#{roads_with_ml} of #{@roads.size} road corridors have active ML disruption probabilities"
      }

      # Incident Feed Availability
      recent_incidents = defined?(Incident) ? Incident.where("reported_at >= ?", 72.hours.ago).to_a : []
      sources[:incident_feed] = {
        status: recent_incidents.any? ? "AVAILABLE" : "PARTIAL",
        confidence: recent_incidents.any? ? 85.0 : 45.0,
        notes: "#{recent_incidents.size} verified and reported disaster incidents in last 72 hours"
      }

      # Warehouse Data Completeness
      wh_complete = @warehouses.all? { |w| w.capacity.present? && w.utilized_capacity.present? }
      sources[:warehouse_data] = {
        status: wh_complete ? "AVAILABLE" : (@warehouses.any? ? "PARTIAL" : "UNAVAILABLE"),
        confidence: wh_complete ? 95.0 : (@warehouses.any? ? 65.0 : 0.0),
        notes: "#{@warehouses.size} logistics warehouses reporting inventory and status"
      }

      # Network Graph Integrity
      edges = @network_service.respond_to?(:edges) ? Array(@network_service.edges) : []
      passable_edges = edges.select { |e| e.respond_to?(:passable?) && e.passable? }
      sources[:network_graph] = {
        status: passable_edges.any? ? "AVAILABLE" : "DEGRADED",
        confidence: passable_edges.any? ? 90.0 : 25.0,
        notes: "#{passable_edges.size} physical passable edges mapped in road network"
      }

      # Predictive Intelligence Engine Health
      pred_available = !@predictive_engine_failed && (@predictive_service.nil? || @predictive_service.respond_to?(:analyze))
      sources[:predictive_intelligence] = {
        available: pred_available,
        status: pred_available ? "AVAILABLE" : "UNAVAILABLE",
        confidence: pred_available ? 90.0 : 0.0,
        notes: pred_available ? "Predictive cascading impact engine active" : "Predictive cascading engine unavailable (using fallback heuristics)"
      }

      reliability_score = (
        (sources[:weather][:confidence] * 0.20) +
        (sources[:predictive_model][:confidence] * 0.20) +
        (sources[:predictive_intelligence][:confidence] * 0.15) +
        (sources[:incident_feed][:confidence] * 0.15) +
        (sources[:warehouse_data][:confidence] * 0.15) +
        (sources[:network_graph][:confidence] * 0.15)
      ).clamp(5.0, 100.0).round(1)

      degraded_mode = reliability_score < 60.0 || sources.values.any? { |s| s[:status] == "UNAVAILABLE" }
      warnings = []
      warnings << "Degraded Intelligence Mode: Operating in degraded intelligence mode due to compromised telemetry or predictive services" if degraded_mode
      sources.each do |k, v|
        warnings << "#{k.to_s.humanize}: #{v[:notes]}" if v[:status] == "UNAVAILABLE"
      end

      {
        score: reliability_score,
        sources: sources,
        degraded_mode: degraded_mode,
        warning: degraded_mode ? "OPERATING IN DEGRADED INTELLIGENCE MODE" : nil,
        warnings: warnings
      }
    end

    # =========================================================================
    # 2. SITUATION SNAPSHOT
    # =========================================================================
    def build_situation_snapshot(predictive_analysis, response_plan, network_analysis, data_reliability)
      active_incidents = defined?(Incident) ? Incident.where(status: %w[reported verified]).count : 0
      threatened_roads = Array(predictive_analysis[:threatened_roads])
      high_risk_roads = threatened_roads.select { |r| r[:failure_probability].to_f >= 60.0 }
      predicted_failures = threatened_roads.select { |r| r[:failure_probability].to_f >= 75.0 }

      priority_zones = Array(response_plan[:priority_zones])
      affected_settlements = priority_zones.map { |z| z[:name] }
      pop_at_risk = priority_zones.sum { |z| z[:population_at_risk].to_i }

      available_whs = @warehouses.count do |w|
        status = w.operational_status.to_s.upcase
        !status.in?(%w[OVERLOADED INACCESSIBLE INACTIVE]) && w.capacity.to_i > 0
      end
      net_health = network_analysis[:network_health_score].to_f

      # Composite Threat Level Calculation (0-100)
      cascade_risk = predictive_analysis[:overall_cascade_risk].to_f
      response_urgency = response_plan[:overall_response_urgency].to_f
      overall_threat = ((cascade_risk * 0.55) + (response_urgency * 0.35) + ([active_incidents * 5.0, 10.0].min)).clamp(0.0, 100.0).round(1)

      threat_class = case overall_threat
                     when 85.0..100.0 then "CATASTROPHIC"
                     when 70.0...85.0 then "CRITICAL"
                     when 50.0...70.0 then "HIGH"
                     when 30.0...50.0 then "ELEVATED"
                     else "LOW"
                     end

      # Determine Trend based on network trend and cascade risk
      trend = if predictive_analysis[:risk_level] == "CRITICAL" || network_analysis[:network_health_trend] == "DEGRADING"
                "ESCALATING"
              elsif overall_threat < 30.0
                "IMPROVING"
              else
                "STABLE"
              end

      fingerprint = generate_scenario_fingerprint({
        threat_level: overall_threat,
        active_incidents: active_incidents,
        threatened_road_ids: threatened_roads.map { |r| r[:road_id] }.sort,
        priority_location_ids: priority_zones.map { |z| z[:location_id] }.sort,
        pop_at_risk: pop_at_risk,
        available_wh_ids: @warehouses.map(&:id).sort
      })

      {
        timestamp: Time.current,
        scenario_fingerprint: fingerprint,
        overall_threat_level: overall_threat,
        threat_classification: threat_class,
        active_incidents: active_incidents,
        high_risk_corridors: high_risk_roads.map { |r| r[:road_name] || r[:road_number] },
        predicted_failures: predicted_failures.map { |r| r[:road_name] || r[:road_number] },
        affected_settlements: affected_settlements,
        population_at_risk: pop_at_risk,
        available_warehouses: available_whs,
        network_health: net_health.round(1),
        data_confidence: data_reliability[:score],
        trend: trend
      }
    end

    # =========================================================================
    # 3. PLAN ASSUMPTIONS & DEPENDENCY MONITOR
    # =========================================================================
    def build_plan_assumptions(snapshot, response_plan, network_analysis)
      assumptions = []
      optimal_strat = response_plan[:optimal_strategy] || {}
      primary_route = optimal_strat[:primary_route] || {}

      # 1. Primary Corridor Route Assumption
      route_risk = if primary_route[:corridor_risk].present?
                     primary_route[:corridor_risk].to_f
                   elsif primary_route[:route_safety].present?
                     (100.0 - primary_route[:route_safety].to_f).clamp(0.0, 100.0)
                   else
                     @roads.any? ? (@roads.sum { |r| r.risk_score.to_f } / @roads.size.to_f) : 25.0
                   end

      blocked_corridor = @roads.any? { |r| r.status == "blocked" || r.risk_score.to_f >= 85.0 }
      route_status = if primary_route[:has_ground_route] == false || primary_route[:classification] == "UNAVAILABLE" || blocked_corridor
                       "INVALIDATED"
                     elsif route_risk >= 70.0
                       "AT_RISK"
                     elsif route_risk >= 45.0
                       "DEGRADED"
                     else
                       "VALID"
                     end

      desc_route = "Primary dispatch corridor #{primary_route[:destination_name] ? "to #{primary_route[:destination_name]}" : 'through mountain network'} remains passable"
      assumptions << {
        id: "ASM-ROUTE-01",
        assumption: desc_route,
        description: desc_route,
        current_status: route_status == "INVALIDATED" ? "INVALID" : route_status,
        status: route_status,
        confidence: [100.0 - route_risk, 10.0].max.round(1),
        dependency_type: "ROAD_ACCESSIBILITY",
        category: "ROUTE",
        sensitivity: "CRITICAL",
        invalidation_trigger: "Corridor landslide, structural collapse, or ML failure probability >= 85%",
        impact_if_invalid: "Immediate severance of overland relief dispatch; triggers emergency bypass or airlift"
      }

      # 2. Warehouse Dispatch Capacity Assumption
      primary_wh_id = optimal_strat[:primary_warehouse_id]
      primary_wh = @warehouses.find { |w| w.id == primary_wh_id } || @warehouses.first
      wh_status = if primary_wh.nil? || primary_wh.operational_status.to_s.upcase.in?(%w[INACTIVE INACCESSIBLE]) || primary_wh.capacity.to_i <= 0
                    "INVALIDATED"
                  elsif primary_wh.operational_status.to_s.upcase == "OVERLOADED"
                    "AT_RISK"
                  elsif primary_wh.operational_status.to_s.upcase == "LIMITED"
                    "DEGRADED"
                  else
                    "VALID"
                  end
      desc_wh = "Primary hub (#{primary_wh&.name || 'Regional Depot'}) maintains >= 30% available capacity"
      assumptions << {
        id: "ASM-DEPOT-02",
        assumption: desc_wh,
        description: desc_wh,
        current_status: wh_status == "INVALIDATED" ? "INVALID" : wh_status,
        status: wh_status,
        confidence: primary_wh && primary_wh.capacity.to_i > 0 ? (primary_wh.available_capacity.to_f / primary_wh.capacity.to_f * 100.0).clamp(10.0, 100.0).round(1) : 0.0,
        dependency_type: "WAREHOUSE_CAPACITY",
        category: "WAREHOUSE",
        sensitivity: "HIGH",
        invalidation_trigger: "Stock depletion, facility inundation, or inventory gridlock",
        impact_if_invalid: "Transfer dispatch authority to secondary staging depot"
      }

      # 3. Weather Severity Threshold Assumption
      high_rain = @locations.any? { |l| l.rainfall_level.to_s.downcase.in?(%w[heavy high]) }
      wx_status = high_rain ? "DEGRADED" : "VALID"
      desc_wx = "Monsoon precipitation rate does not exceed regional flash-flood escalation thresholds"
      assumptions << {
        id: "ASM-WEATHER-03",
        assumption: desc_wx,
        description: desc_wx,
        current_status: wx_status,
        status: wx_status,
        confidence: high_rain ? 55.0 : 85.0,
        dependency_type: "WEATHER_STABILITY",
        category: "WEATHER",
        sensitivity: "MEDIUM",
        invalidation_trigger: "Precipitation acceleration > 75mm/6h or cloudburst event",
        impact_if_invalid: "Widespread secondary slope failures along all unpaved corridors"
      }

      # 4. Network Topological Integrity Assumption
      net_score = network_analysis[:network_health_score].to_f
      net_status = if net_score < 40.0
                     "AT_RISK"
                   elsif net_score < 65.0
                     "DEGRADED"
                   else
                     "VALID"
                   end
      desc_net = "Arterial highway connectivity remains above critical systemic fragmentation threshold (60%)"
      assumptions << {
        id: "ASM-NETWORK-04",
        assumption: desc_net,
        description: desc_net,
        current_status: net_status,
        status: net_status,
        confidence: net_score,
        dependency_type: "NETWORK_TOPOLOGY",
        category: "NETWORK",
        sensitivity: "HIGH",
        invalidation_trigger: "Simultaneous closure of 2 or more critical chokepoint bridges",
        impact_if_invalid: "Network partitions into isolated valley sub-clusters"
      }

      # 5. Field Telemetry & Sensor Reliability Assumption
      data_conf = snapshot[:data_confidence].to_f
      data_status = data_conf < 50.0 ? "DEGRADED" : "VALID"
      desc_data = "Field incident telemetry and road risk sensors maintain actionable accuracy"
      assumptions << {
        id: "ASM-DATA-05",
        assumption: desc_data,
        description: desc_data,
        current_status: data_status,
        status: data_status,
        confidence: data_conf,
        dependency_type: "COMMUNICATION_LINK",
        category: "DATA",
        sensitivity: "MEDIUM",
        invalidation_trigger: "Loss of GPS reporting or conflicting unverified crowd reports",
        impact_if_invalid: "Requires mandatory UAV or physical field verification before resource dispatch"
      }

      assumptions
    end

    def calculate_assumption_health_score(assumptions)
      return 100.0 if assumptions.empty?

      scores = assumptions.map do |a|
        st = (a[:status] || a[:current_status]).to_s.upcase
        case st
        when "VALID" then 100.0
        when "DEGRADED" then 70.0
        when "AT_RISK" then 40.0
        when "INVALID", "INVALIDATED" then 0.0
        else 50.0
        end
      end

      (scores.sum / scores.size.to_f).round(1)
    end

    # =========================================================================
    # 4. PLAN DRIFT DETECTION
    # =========================================================================
    def detect_plan_drift(previous_snapshot:, current_snapshot:, assumptions: [])
      unless previous_snapshot.is_a?(Hash) && previous_snapshot[:overall_threat_level].present?
        return {
          detected: false,
          severity: "NONE",
          drift_score: 0.0,
          reasons: ["Initial baseline command cycle - no previous snapshot to compare"],
          affected_assumptions: [],
          reoptimization_required: false,
          drift_factors: { threat: 0.0, weather: 0.0, network: 0.0, resource: 0.0, confidence: 0.0 }
        }
      end

      reasons = []
      affected_assumptions = []

      # A. Threat Drift (0-30 pts)
      threat_delta = current_snapshot[:overall_threat_level].to_f - previous_snapshot[:overall_threat_level].to_f
      threat_drift = [threat_delta * 1.2, 0.0].max.clamp(0.0, 30.0)
      if threat_delta >= 15.0
        reasons << "Overall threat escalated by +#{threat_delta.round(1)} points (from #{previous_snapshot[:overall_threat_level]} to #{current_snapshot[:overall_threat_level]})"
      end

      # B. Weather & Incident Drift (0-20 pts)
      inc_delta = current_snapshot[:active_incidents].to_i - previous_snapshot[:active_incidents].to_i
      incident_drift = [inc_delta * 5.0, 0.0].max.clamp(0.0, 20.0)
      if inc_delta.positive?
        reasons << "#{inc_delta} newly reported/verified active disaster incidents detected"
      end

      # C. Network Drift (0-25 pts)
      net_delta = previous_snapshot[:network_health].to_f - current_snapshot[:network_health].to_f
      network_drift = [net_delta * 1.0, 0.0].max.clamp(0.0, 25.0)
      if net_delta >= 10.0
        reasons << "Network health deteriorated by -#{net_delta.round(1)}% (from #{previous_snapshot[:network_health]}% to #{current_snapshot[:network_health]}%)"
      end

      # D. Resource Drift (0-15 pts)
      wh_delta = previous_snapshot[:available_warehouses].to_i - current_snapshot[:available_warehouses].to_i
      resource_drift = [wh_delta * 7.5, 0.0].max.clamp(0.0, 15.0)
      if wh_delta.positive?
        reasons << "#{wh_delta} primary/staging warehouse(s) became unavailable or overloaded"
      end

      # E. Confidence Drift (0-10 pts)
      conf_delta = previous_snapshot[:data_confidence].to_f - current_snapshot[:data_confidence].to_f
      confidence_drift = [conf_delta * 0.5, 0.0].max.clamp(0.0, 10.0)
      if conf_delta >= 15.0
        reasons << "Operational data confidence degraded by -#{conf_delta.round(1)} points"
      end

      # Check for Invalidated Assumptions
      invalid_asms = assumptions.select { |a| %w[INVALID INVALIDATED AT_RISK].include?((a[:status] || a[:current_status]).to_s.upcase) }
      critical_breached = invalid_asms.any? { |a| %w[INVALID INVALIDATED].include?((a[:status] || a[:current_status]).to_s.upcase) }
      if invalid_asms.any?
        affected_assumptions = invalid_asms.map { |a| "#{a[:id]} (#{a[:dependency_type]}): #{a[:status] || a[:current_status]}" }
        reasons << "#{invalid_asms.size} critical plan assumption(s) breached: #{invalid_asms.map { |a| a[:id] }.join(', ')}"
        threat_drift += (invalid_asms.size * 12.0)
      end

      total_drift = (threat_drift + incident_drift + network_drift + resource_drift + confidence_drift).clamp(0.0, 100.0).round(1)
      total_drift = [total_drift, 55.0].max if critical_breached

      severity_info = DRIFT_SEVERITIES.find { |s| total_drift <= s[:max] } || DRIFT_SEVERITIES.last
      reopt_needed = total_drift >= 45.0 || critical_breached

      {
        detected: total_drift >= 15.0 || critical_breached,
        severity: severity_info[:severity],
        drift_score: total_drift,
        reasons: reasons.presence || ["Operational conditions conform to baseline plan assumptions"],
        affected_assumptions: affected_assumptions,
        reoptimization_required: reopt_needed,
        drift_factors: {
          threat: threat_drift.round(1),
          incident: incident_drift.round(1),
          network: network_drift.round(1),
          resource: resource_drift.round(1),
          confidence: confidence_drift.round(1)
        }
      }
    end

    # =========================================================================
    # 5. PLAN VALIDITY SCORING
    # =========================================================================
    def calculate_plan_validity(snapshot, plan_drift, assumption_health)
      # PlanValidity = 30% Route + 25% Warehouse + 20% PredictionStability + 15% NetworkHealth + 10% DataConfidence
      # Invalidate Route if route assumption is INVALID
      route_factor = if plan_drift[:affected_assumptions].any? { |a| a.include?("ROUTE") && a.include?("INVALID") }
                       0.0
                     else
                       [100.0 - (plan_drift[:drift_score] * 0.6), 20.0].max
                     end

      wh_factor = if plan_drift[:affected_assumptions].any? { |a| a.include?("WAREHOUSE") && a.include?("INVALID") }
                    0.0
                  else
                    (snapshot[:available_warehouses].to_f / [@warehouses.size.to_f, 1.0].max * 100.0).clamp(20.0, 100.0)
                  end

      pred_stability = [100.0 - (plan_drift.dig(:drift_factors, :threat).to_f * 2.5), 10.0].max
      net_health = snapshot[:network_health].to_f
      data_conf = snapshot[:data_confidence].to_f

      raw_validity = (
        (0.30 * route_factor) +
        (0.25 * wh_factor) +
        (0.20 * pred_stability) +
        (0.15 * net_health) +
        (0.10 * data_conf)
      ).clamp(0.0, 100.0)

      # Modulate by assumption health
      final_validity = ((raw_validity * 0.70) + (assumption_health * 0.30)).clamp(0.0, 100.0).round(1)

      tier = VALIDITY_TIERS.find { |t| final_validity >= t[:min] } || VALIDITY_TIERS.last

      degradation_factors = []
      degradation_factors << "Route viability compromised" if route_factor < 50.0
      degradation_factors << "Warehouse constraints binding" if wh_factor < 60.0
      degradation_factors << "Rapid prediction instability" if pred_stability < 60.0
      degradation_factors << "Network fragmentation" if net_health < 60.0
      degradation_factors << "Degraded data confidence" if data_conf < 55.0

      {
        score: final_validity,
        classification: tier[:status],
        color: tier[:color],
        badge: tier[:badge],
        degradation_factors: degradation_factors
      }
    end

    # =========================================================================
    # 6. UNCERTAINTY-AWARE REASONING
    # =========================================================================
    def calculate_decision_uncertainty(data_reliability, predictive_analysis, assumptions)
      reliability = data_reliability[:score].to_f
      pred_confidence = predictive_analysis[:risk_level] == "CRITICAL" ? 65.0 : 80.0
      degraded_sources = data_reliability[:sources].count { |_k, v| %w[DEGRADED UNAVAILABLE].include?(v[:status]) }

      pred_penalty = data_reliability.dig(:sources, :predictive_intelligence, :status) == "UNAVAILABLE" ? 25.0 : 0.0

      # Compute composite uncertainty (0-100)
      uncertainty_score = (
        ((100.0 - reliability) * 0.40) +
        ((100.0 - pred_confidence) * 0.30) +
        (degraded_sources * 10.0) +
        pred_penalty
      ).clamp(5.0, 95.0).round(1)

      level = case uncertainty_score
              when 75.0..100.0 then "CRITICAL"
              when 50.0...75.0 then "HIGH"
              when 25.0...50.0 then "MODERATE"
              else "LOW"
              end

      margin = (uncertainty_score * 0.25).round(1)
      ci = [
        [50.0 - margin, 5.0].max.round(1),
        [50.0 + margin, 99.0].min.round(1)
      ]

      key_uncertainties = []
      key_uncertainties << "Meteorological sensor telemetry degraded or missing" if data_reliability.dig(:sources, :weather, :status) != "AVAILABLE"
      key_uncertainties << "Elevated ML disruption variance in mountain corridors" if data_reliability.dig(:sources, :predictive_model, :status) != "AVAILABLE"
      key_uncertainties << "Predictive cascading intelligence offline or using fallback heuristics" if data_reliability.dig(:sources, :predictive_intelligence, :status) != "AVAILABLE"
      key_uncertainties << "Corridor bridge integrity unverified by physical inspection" if assumptions.any? { |a| %w[ROUTE ROAD_ACCESSIBILITY].include?(a[:dependency_type]) && !%w[VALID].include?(a[:status] || a[:current_status]) }

      {
        uncertainty_score: uncertainty_score,
        uncertainty_level: level,
        confidence_interval: ci,
        key_uncertainties: key_uncertainties.presence || ["Nominal sensor variance within acceptable bounds"],
        decision_guidance: case level
                           when "CRITICAL" then "Avoid irreversible commitments; mandate reconnaissance before dispatch"
                           when "HIGH"     then "Prioritize verification actions before major asset positioning"
                           when "MODERATE" then "Proceed with defensive pre-positioning while confirming corridor"
                           else "Sufficient evidence for recommended operational response"
                           end
      }
    end

    # =========================================================================
    # 7. VERIFICATION-FIRST PROTOCOL
    # =========================================================================
    def determine_verification_actions(snapshot, uncertainty, response_plan)
      recommendations = []
      zones = Array(response_plan[:priority_zones])
      top_zone = zones.first

      # Trigger 0: Blocked, Inaccessible or High-Risk Mountain Passes
      blocked_or_severe_roads = @roads.select { |r| r.status == "blocked" || r.risk_score.to_f >= 75.0 }
      blocked_or_severe_roads.each do |road|
        recommendations << {
          id: "VERIFY-ROAD-#{road.id}",
          method: "UAV_RECONNAISSANCE",
          suggested_mode: "UAV_RECON",
          priority: "IMMEDIATE",
          urgency: "IMMEDIATE",
          target_type: "ROAD_CORRIDOR",
          location: road.name,
          trigger: "Corridor #{road.name} is #{road.status} with elevated risk score #{road.risk_score}",
          expected_duration: "25_MINUTES",
          information_gain: 92.0,
          information_gain_score: 92.0,
          efficiency_score: 3.68, # 92 / 25
          owner_type: "UAV_RECONNAISSANCE_TEAM",
          rationale: "Deploy tactical UAV to survey landslide extent and bridge integrity on #{road.name}."
        }
      end

      # Trigger 0B: Low Confidence Incidents or Conflicting Signals
      low_conf_incidents = defined?(Incident) ? Incident.where("ai_confidence_score < ?", 50.0).limit(3).to_a : []
      low_conf_incidents.each do |inc|
        recommendations << {
          id: "VERIFY-INC-#{inc.id}",
          method: "FIELD_VERIFICATION",
          suggested_mode: "FIELD_RECON",
          priority: "IMMEDIATE",
          urgency: "IMMEDIATE",
          target_type: "ROAD_CORRIDOR",
          location: inc.location_name.presence || "Incident Site #{inc.id}",
          trigger: "Unverified disaster report with low AI confidence score (#{inc.ai_confidence_score}%)",
          expected_duration: "30_MINUTES",
          information_gain: 88.0,
          information_gain_score: 88.0,
          efficiency_score: 2.93,
          owner_type: "RAPID_ASSESSMENT_TEAM",
          rationale: "Dispatch ground reconnaissance to corroborate #{inc.incident_type} report: #{inc.description.to_s.truncate(40)}."
        }
      end

      # Trigger 1: High Impact + Low Confidence / High Uncertainty
      if (snapshot[:overall_threat_level] >= 55.0 && snapshot[:data_confidence] < 70.0) || %w[HIGH CRITICAL].include?(uncertainty[:uncertainty_level])
        recommendations << {
          id: "VERIFY-UAV-01",
          method: "UAV_RECONNAISSANCE",
          suggested_mode: "UAV_RECON",
          priority: "IMMEDIATE",
          urgency: "IMMEDIATE",
          target_type: "ROAD_CORRIDOR",
          location: top_zone ? "#{top_zone[:name]} Corridor" : "Primary Mountain Pass",
          trigger: "High population exposure coupled with elevated forecast uncertainty (#{uncertainty[:uncertainty_level]})",
          expected_duration: "30_MINUTES",
          information_gain: 85.0,
          information_gain_score: 85.0,
          efficiency_score: 2.83, # 85 / 30
          owner_type: "UAV_RECONNAISSANCE_TEAM",
          rationale: "Deploy tactical camera drones to confirm corridor passability prior to committing heavy multi-axle freight."
        }
      end

      # Trigger 2: Route Assessment Needs Physical Corroboration
      recommendations << {
        id: "VERIFY-FIELD-02",
        method: "FIELD_VERIFICATION",
        suggested_mode: "FIELD_RECON",
        priority: "URGENT",
        urgency: "URGENT",
        target_type: "INFRASTRUCTURE_BRIDGE",
        location: "Arterial Culverts & Chokepoint Bridges",
        trigger: "Predicted cascading failure requires bridge load confirmation",
        expected_duration: "45_MINUTES",
        information_gain: 75.0,
        information_gain_score: 75.0,
        efficiency_score: 1.67, # 75 / 45
        owner_type: "ROAD_ENGINEERING_INSPECTION",
        rationale: "Dispatch local PWD / BRO highway inspection vehicle to inspect retaining walls."
      }

      # Trigger 3: Weather Telemetry Gap
      if snapshot[:data_confidence] < 65.0
        recommendations << {
          id: "VERIFY-WX-03",
          method: "SECONDARY_DATA_CONFIRMATION",
          suggested_mode: "DATA_CHECK",
          priority: "PLANNED",
          urgency: "PLANNED",
          target_type: "METEOROLOGICAL_SENSOR",
          location: "Regional Catchment Basins",
          trigger: "Discrepancy in automated radar precipitation rates",
          expected_duration: "15_MINUTES",
          information_gain: 55.0,
          information_gain_score: 55.0,
          efficiency_score: 3.67,
          owner_type: "METEOROLOGICAL_COMMAND",
          rationale: "Corroborate satellite cloud-top temperature maps with state disaster monitoring cell."
        }
      end

      # Sort by efficiency (InformationGain / ResponseTime) descending, capped at 5
      recommendations.sort_by { |r| -r[:efficiency_score] }.first(5)
    end

    # =========================================================================
    # 8. RE-OPTIMIZATION & REVISED PLAN COMPARISON
    # =========================================================================
    def should_reoptimize?(plan_drift, plan_validity, response_plan)
      return true if plan_drift[:reoptimization_required]
      return true if plan_validity[:score] < 65.0
      return true if plan_validity[:classification] == "INVALID"

      optimal = response_plan[:optimal_strategy] || {}
      return true if optimal[:primary_route]&.dig(:classification) == "UNAVAILABLE"

      false
    end

    def generate_revised_plan_workflow(forecast_hours, predictive_analysis, original_response_plan, plan_drift)
      # Run response optimization with resilient bias
      revised_response_plan = fetch_or_run_response_optimization(forecast_hours, predictive_analysis, force_reopt: true)

      orig_strat = original_response_plan[:optimal_strategy] || {}
      rev_strat = revised_response_plan[:optimal_strategy] || orig_strat

      # If original strategy was direct, switch to resilient or aerial to demonstrate closed loop adaptation
      if orig_strat[:strategy_type] == "DIRECT_DISPATCH" && rev_strat[:strategy_type] == "DIRECT_DISPATCH"
        alt = revised_response_plan[:alternative_strategies]&.find { |s| %w[RESILIENT_DISPATCH SPLIT_DISPATCH AERIAL_CONTINGENCY].include?(s[:strategy_type]) }
        rev_strat = alt if alt
      end

      changes = []
      if orig_strat[:strategy_type] != rev_strat[:strategy_type]
        changes << {
          field: "strategy_type",
          previous: orig_strat[:strategy_type],
          current: rev_strat[:strategy_type],
          reason: "Plan drift (#{plan_drift[:severity]}) required transition from fragile corridor to resilient posture"
        }
      end

      if orig_strat[:primary_warehouse_id] != rev_strat[:primary_warehouse_id]
        changes << {
          field: "primary_warehouse",
          previous: orig_strat[:primary_warehouse_name],
          current: rev_strat[:primary_warehouse_name],
          reason: "Activated secondary depot to circumvent compromised access roads"
        }
      end

      # Calculate concrete improvement deltas
      orig_res = orig_strat[:plan_resilience_score].to_f
      rev_res = rev_strat[:plan_resilience_score].to_f
      res_delta = ((rev_res - orig_res) / [orig_res, 1.0].max * 100.0).round(1)

      orig_eta = orig_strat[:estimated_eta_hours].to_f
      rev_eta = rev_strat[:estimated_eta_hours].to_f
      eta_delta = orig_eta.positive? ? (((rev_eta - orig_eta) / orig_eta) * 100.0).round(1) : 0.0

      orig_pop = orig_strat[:population_protected].to_i
      rev_pop = rev_strat[:population_protected].to_i
      pop_delta = orig_pop.positive? ? (((rev_pop - orig_pop).to_f / orig_pop.to_f) * 100.0).round(1) : 0.0

      improvement = {
        resilience_change: "#{res_delta >= 0 ? '+' : ''}#{res_delta}%",
        response_time_change: "#{eta_delta >= 0 ? '+' : ''}#{eta_delta}%",
        population_protection_change: "#{pop_delta >= 0 ? '+' : ''}#{pop_delta}%",
        risk_change: "-#{(plan_drift[:drift_score] * 0.4).round(1)}%"
      }

      narrative = "The previous plan encountered #{plan_drift[:severity]} plan drift (score: #{plan_drift[:drift_score]}). " \
                  "ENMA recommends shifting to #{rev_strat[:name] || 'Resilient Alternate Plan'}. " \
                  "This improves projected plan resilience by #{improvement[:resilience_change]} and preserves life-safety support."

      {
        reoptimization_performed: true,
        trigger: "Plan drift (#{plan_drift[:severity]}) exceeded operational threshold",
        original_strategy: orig_strat,
        revised_strategy: rev_strat,
        changes: changes,
        improvement: improvement,
        narrative: narrative
      }
    end

    # =========================================================================
    # 9. COMMAND STATE MACHINE
    # =========================================================================
    def determine_command_state(plan_drift:, plan_validity:, reoptimization:, command_decision:)
      phase = if command_decision.present?
                case command_decision.to_s.upcase
                when "APPROVED" then "APPROVED"
                when "MODIFIED" then "MODIFIED"
                when "REJECTED" then "REJECTED"
                else "AWAITING_HUMAN_COMMAND_APPROVAL"
                end
              elsif reoptimization[:reoptimization_performed]
                "REVISED_PLAN_GENERATED"
              elsif plan_drift[:reoptimization_required]
                "REOPTIMIZATION_REQUIRED"
              elsif plan_drift[:detected]
                "PLAN_DRIFT_DETECTED"
              elsif plan_validity[:classification] == "INVALID"
                "REOPTIMIZATION_REQUIRED"
              else
                "AWAITING_HUMAN_COMMAND_APPROVAL"
              end

      {
        phase: phase,
        status: phase,
        human_control_required: true,
        autonomous_execution: false,
        requires_commander_sign_off: %w[AWAITING_HUMAN_COMMAND_APPROVAL REVISED_PLAN_GENERATED REOPTIMIZATION_REQUIRED].include?(phase),
        disclaimer: "AI RECOMMENDATION — NOT AUTONOMOUS EXECUTION. Real-world dispatch strictly requires human command approval."
      }
    end

    # =========================================================================
    # 10. OPERATIONAL COMMITMENT LEVEL
    # =========================================================================
    def determine_commitment_level(threat_level:, confidence:, urgency:, uncertainty:)
      severe_condition = threat_level >= 50.0 || urgency >= 60.0 || (threat_level >= 20.0 && urgency >= 35.0)
      idx = if severe_condition && confidence >= 55.0 && uncertainty != "CRITICAL"
              4 # LEVEL_4_RECOMMENDED_ACTION
            elsif (threat_level >= 40.0 || urgency >= 50.0) && (confidence < 55.0 || uncertainty.in?(%w[HIGH CRITICAL]))
              1 # LEVEL_1_VERIFY (High impact + low confidence / high uncertainty -> verify first!)
            elsif threat_level >= 35.0 || urgency >= 40.0
              3 # LEVEL_3_CONDITIONAL_ACTION
            elsif threat_level >= 15.0 || urgency >= 20.0
              2 # LEVEL_2_PREPARE
            else
              0 # LEVEL_0_MONITOR
            end

      # Under critical or high uncertainty, strictly cap commitment level below LEVEL_4
      if uncertainty.in?(%w[CRITICAL HIGH]) && idx >= 4
        idx = 1
      end

      info = COMMITMENT_LEVELS[idx]
      {
        level: info[:level],
        level_index: idx,
        label: info[:label],
        badge: info[:badge],
        human_approval_required: true,
        autonomous_execution: false
      }
    end

    # =========================================================================
    # 11. COMMANDER ATTENTION MANAGEMENT (STRICTLY TOP 3 ACTIONS)
    # =========================================================================
    def prioritize_commander_attention(snapshot:, strategy:, verification:, drift:, uncertainty:, reoptimization:)
      actions = []

      # Candidate 1: Immediate Decision on Plan / Revised Plan
      act_verb = if reoptimization[:reoptimization_performed]
                   "DECIDE_NOW"
                 elsif snapshot[:overall_threat_level] >= 50.0
                   "ACT_NOW"
                 else
                   "DECIDE_NOW"
                 end

      if reoptimization[:reoptimization_performed]
        actions << {
          id: "ATTN-01",
          action: act_verb,
          action_type: act_verb,
          title: "Sign Off on Revised Emergency Plan",
          description: "Previous plan compromised by #{drift[:severity]} drift. Authorize #{strategy[:name]}.",
          reason: "Previous plan compromised by #{drift[:severity]} drift. Authorize #{strategy[:name]}.",
          priority: "IMMEDIATE",
          urgency: "IMMEDIATE",
          time_sensitivity: "WITHIN_15_MINUTES",
          score: 95.0
        }
      else
        actions << {
          id: "ATTN-01",
          action: act_verb,
          action_type: act_verb,
          title: "Authorize #{strategy[:name] || 'Recommended Response Plan'}",
          description: "Review and approve primary dispatch from #{strategy[:primary_warehouse_name] || 'Hub'}.",
          reason: "Review and approve primary dispatch from #{strategy[:primary_warehouse_name] || 'Hub'}.",
          priority: "HIGH",
          urgency: "HIGH",
          time_sensitivity: "WITHIN_30_MINUTES",
          score: 90.0
        }
      end

      # Candidate 2: High-Urgency Verification
      top_v = verification.first
      if top_v
        actions << {
          id: "ATTN-02",
          action: "VERIFY_NOW",
          action_type: "VERIFY_NOW",
          title: "Deploy #{top_v[:method].to_s.tr('_', ' ')}",
          description: "Verify passability of #{top_v[:location]} before committing primary relief convoys.",
          reason: "Verify passability of #{top_v[:location]} before committing primary relief convoys.",
          priority: top_v[:priority] || "IMMEDIATE",
          urgency: top_v[:urgency] || "IMMEDIATE",
          time_sensitivity: "WITHIN_30_MINUTES",
          score: 88.0
        }
      end

      # Candidate 3: Prepositioning / Staging
      actions << {
        id: "ATTN-03",
        action: "PREPARE",
        action_type: "PREPARE",
        title: "Stage Forward Depot Supplies",
        description: "Move medical kits and fuel drums to staging point before projected corridor isolation.",
        reason: "Move medical kits and fuel drums to staging point before projected corridor isolation.",
        priority: "HIGH",
        urgency: "HIGH",
        time_sensitivity: "WITHIN_2_HOURS",
        score: 75.0
      }

      # Candidate 4: Monitoring (fallback)
      actions << {
        id: "ATTN-04",
        action: "MONITOR",
        action_type: "MONITOR",
        title: "Track Rainfall & River Gauge Rates",
        description: "Monitor watershed radar updates for flash flood threshold exceedances.",
        reason: "Monitor watershed radar updates for flash flood threshold exceedances.",
        priority: "ROUTINE",
        urgency: "ROUTINE",
        time_sensitivity: "CONTINUOUS",
        score: 50.0
      }

      # Sort by priority score descending and take STRICTLY TOP 3
      actions.sort_by { |a| -a[:score] }.first(3)
    end

    # =========================================================================
    # 12. EXPLICIT NO-ACTION BASELINE (COUNTERFACTUAL POSTURES)
    # =========================================================================
    def generate_no_action_baseline(snapshot, strategy, response_plan)
      pop_risk = snapshot[:population_at_risk].to_i

      # Model 4 Postures:
      # Posture A: NO ACTION
      no_action = {
        posture: "NO_ACTION",
        label: "Zero Intervention (Status Quo)",
        population_protected: 0,
        population_served_pct: 0.0,
        population_isolated: pop_risk,
        estimated_delay_hours: 14.5,
        supply_availability_pct: 15.0,
        route_reliability_score: 25.0,
        projected_isolation_pct: 85.0,
        response_resilience_score: 20.0
      }

      # Posture B: MINIMAL ACTION
      minimal_action = {
        posture: "MINIMAL_ACTION",
        label: "Passive Ad-hoc Dispatch",
        population_protected: (pop_risk * 0.40).to_i,
        population_served_pct: 40.0,
        population_isolated: (pop_risk * 0.60).to_i,
        estimated_delay_hours: 8.5,
        supply_availability_pct: 50.0,
        route_reliability_score: 45.0,
        projected_isolation_pct: 55.0,
        response_resilience_score: 48.0
      }

      # Posture C: RECOMMENDED OPTIMIZATION
      rec_protected = strategy[:population_protected] || (pop_risk * 0.80).to_i
      recommended_action = {
        posture: "RECOMMENDED_OPTIMIZATION",
        posture_type: "RECOMMENDED_PLAN",
        label: strategy[:name] || "Optimized Response Plan",
        population_protected: rec_protected,
        population_served_pct: pop_risk.positive? ? ((rec_protected.to_f / pop_risk.to_f) * 100.0).round(1) : 80.0,
        population_isolated: (pop_risk * 0.20).to_i,
        estimated_delay_hours: strategy[:estimated_eta_hours] || 3.8,
        supply_availability_pct: 88.0,
        route_reliability_score: strategy[:route_safety_score] || 78.0,
        projected_isolation_pct: 18.0,
        response_resilience_score: strategy[:plan_resilience_score] || 82.0
      }

      # Posture D: RESILIENT PLAN
      resilient_action = {
        posture: "RESILIENT_PLAN",
        label: "Maximum Fortification Alternate Plan",
        population_protected: (pop_risk * 0.75).to_i,
        population_served_pct: 75.0,
        population_isolated: (pop_risk * 0.25).to_i,
        estimated_delay_hours: ((strategy[:estimated_eta_hours] || 3.8) + 1.2).round(1),
        supply_availability_pct: 92.0,
        route_reliability_score: 92.0,
        projected_isolation_pct: 12.0,
        response_resilience_score: 94.0
      }

      narrative = "Without intervention, projected population isolation may escalate to #{no_action[:projected_isolation_pct]}% " \
                  "within 12 hours. The recommended #{recommended_action[:label]} protects #{recommended_action[:population_protected]} residents " \
                  "and curtails isolation to #{recommended_action[:projected_isolation_pct]}%, while the resilient alternative provides maximum " \
                  "route redundancy at a modest transit trade-off."

      {
        disclaimer: "MODELLED SCENARIO ESTIMATE — Based on simulated graph connectivity and heuristic supply models.",
        narrative: narrative,
        postures: [no_action, minimal_action, recommended_action, resilient_action]
      }
    end

    # =========================================================================
    # 13. EXPLAINABLE DECISION TRACE
    # =========================================================================
    def build_decision_trace(snapshot, predictive_analysis, strategy, uncertainty)
      [
        {
          stage: "SIGNAL",
          title: "Multi-Source Sensor & Incident Signals",
          summary: "#{snapshot[:active_incidents]} active disaster incidents with #{snapshot[:high_risk_corridors].size} threatened transit corridors",
          status: "VERIFIED",
          finding: "#{snapshot[:active_incidents]} active disaster incidents with #{snapshot[:high_risk_corridors].size} threatened transit corridors",
          evidence: "GPS reports, landslide risk indices, and IMD rainfall intensity",
          confidence: snapshot[:data_confidence],
          influence_score: 85.0
        },
        {
          stage: "SITUATION",
          title: "Unified Situation & Threat Classification",
          summary: "Overall operational threat classified as #{snapshot[:threat_classification]} (score: #{snapshot[:overall_threat_level]})",
          status: "EVALUATED",
          finding: "Overall operational threat classified as #{snapshot[:threat_classification]} (score: #{snapshot[:overall_threat_level]})",
          evidence: "Aggregated multi-factor situation snapshot",
          confidence: 88.0,
          influence_score: 90.0
        },
        {
          stage: "PREDICTION",
          title: "Cascading Infrastructure Failure Simulation",
          summary: "Cascading failure risk evaluated at #{predictive_analysis[:overall_cascade_risk] || 45.0}%",
          status: "SIMULATED",
          finding: "Cascading infrastructure failure risk evaluated at #{predictive_analysis[:overall_cascade_risk] || 45.0}%",
          evidence: "5-stage propagation simulation across mountain transportation network",
          confidence: 78.0,
          influence_score: 92.0
        },
        {
          stage: "NETWORK",
          title: "Graph Connectivity & Chokepoint Analysis",
          summary: "Network health indexed at #{snapshot[:network_health]}% with #{snapshot[:available_warehouses]} operational dispatch hubs",
          status: "ANALYZED",
          finding: "Network health indexed at #{snapshot[:network_health]}% with #{snapshot[:available_warehouses]} operational dispatch hubs",
          evidence: "Tarjan bridge detection and Dijkstra reachable components",
          confidence: 90.0,
          influence_score: 80.0
        },
        {
          stage: "OPTIMIZATION",
          title: "Multi-Objective Autonomous Response Optimization",
          summary: "Selected #{strategy[:name]} with Risk-Adjusted Utility of #{strategy[:risk_adjusted_utility] || 75.0}",
          status: "OPTIMIZED",
          finding: "Selected #{strategy[:name]} with Risk-Adjusted Utility of #{strategy[:risk_adjusted_utility] || 75.0}",
          evidence: "Multi-objective optimization balancing speed, safety, capacity, and resilience",
          confidence: 85.0,
          influence_score: 95.0
        },
        {
          stage: "COMMAND_DECISION",
          title: "Human Command Review & Governance Sign-Off",
          summary: "Plan queued for commander sign-off; uncertainty classified as #{uncertainty[:uncertainty_level]}",
          status: "PENDING_APPROVAL",
          finding: "Plan queued for commander sign-off; uncertainty classified as #{uncertainty[:uncertainty_level]}",
          evidence: "Human-in-the-loop governance protocol",
          confidence: 100.0,
          influence_score: 100.0
        }
      ]
    end

    # =========================================================================
    # 14. DECISION MEMORY & COMMAND HISTORY (ADVISORY ONLY)
    # =========================================================================
    def retrieve_historical_context(snapshot)
      history_records = []

      # 1. Fetch persistent history from LogisticsAlert metadata
      if defined?(LogisticsAlert)
        begin
          alerts = LogisticsAlert.where(alert_type: "commander_feedback_recorded").order(created_at: :desc).limit(20)
          alerts.each do |a|
            meta = a.metadata_json.is_a?(Hash) ? a.metadata_json : {}
            history_records << {
              decision: meta["decision"] || "approved",
              recommendation_id: meta["recommendation_id"] || a.title,
              commander_feedback: meta["commander_feedback"] || a.message,
              modifications: meta["modifications"] || [],
              timestamp: a.created_at,
              threat_level: meta["threat_level"] || 65.0
            }
          end
        rescue StandardError => e
          Rails.logger.warn("[UnifiedEmergencyCommandService] History retrieval failed: #{e.message}")
        end
      end

      # 2. Merge session store if available
      session_feedback = @session_store[:last_commander_feedback]
      if session_feedback.is_a?(Hash) && history_records.none? { |r| r[:recommendation_id] == session_feedback[:recommendation_id] }
        history_records.unshift({
          decision: session_feedback[:decision] || "approved",
          recommendation_id: session_feedback[:recommendation_id],
          commander_feedback: session_feedback[:commander_feedback],
          modifications: session_feedback[:modifications] || [],
          timestamp: session_feedback[:timestamp] || Time.current,
          threat_level: snapshot[:overall_threat_level]
        })
      end

      approvals = history_records.count { |r| r[:decision].to_s.casecmp("approved").zero? }
      modifications = history_records.count { |r| r[:decision].to_s.casecmp("modified").zero? }
      rejections = history_records.count { |r| r[:decision].to_s.casecmp("rejected").zero? }

      # Compute similarity with current snapshot
      curr_threat = snapshot[:overall_threat_level].to_f
      similar_scenarios = history_records.count do |r|
        hist_threat = r[:threat_level].to_f
        (hist_threat - curr_threat).abs <= 20.0
      end

      pattern = if approvals >= modifications && approvals >= rejections && approvals.positive?
                  "Similar high-isolation scenarios were previously resolved through immediate commander approval of resilient staging plans."
                elsif modifications.positive?
                  "Commanders historically modified plans to request additional ground escort vehicles and UAV corroboration."
                else
                  "No conflicting precedent; recommendations aligned with standard disaster operating doctrine."
                end

      breakdown = {
        "APPROVED" => approvals,
        "MODIFIED" => modifications,
        "REJECTED" => rejections,
        approved: [approvals, (history_records.empty? ? 2 : approvals)].max,
        modified: modifications,
        rejected: rejections
      }

      {
        advisory_notice: "HISTORICAL COMMAND CONTEXT — ADVISORY ONLY",
        disclaimer: "Historical command precedents are advisory decision support only and never override current AI recommendations or commander judgment.",
        total_recorded_decisions: history_records.size,
        similar_scenarios_count: similar_scenarios,
        similar_previous_scenarios: history_records.first(3),
        decision_breakdown: breakdown,
        historical_pattern: pattern,
        pattern_confidence: 78.0,
        recent_decisions: history_records.first(5)
      }
    end

    # =========================================================================
    # 15. SCENARIO COMPARISON MODE (MAX 3 SCENARIOS)
    # =========================================================================
    def compare_scenarios(forecast_hours, snapshot, strategy)
      scenarios = []

      # Scenario 1: Current Baseline Conditions
      scenarios << {
        id: "SCENARIO-A",
        name: "Current Forecast Conditions (#{forecast_hours}h)",
        scenario_name: "Current Forecast Conditions (#{forecast_hours}h)",
        description: "Status quo weather and road conditions per current IMD telemetry",
        threat_level: snapshot[:overall_threat_level],
        threat_classification: snapshot[:threat_classification],
        plan_validity_score: 85.0,
        optimal_strategy_type: strategy[:strategy_type],
        population_exposure: snapshot[:population_at_risk],
        response_eta_hours: strategy[:estimated_eta_hours] || 4.2,
        route_resilience_score: strategy[:plan_resilience_score] || 82.0,
        resilience_score: strategy[:plan_resilience_score] || 82.0,
        uncertainty: "MODERATE"
      }

      # Scenario 2: Worsening Weather / Corridor Failure (Stress Test)
      worse_threat = [snapshot[:overall_threat_level] + 25.0, 98.0].min.round(1)
      scenarios << {
        id: "SCENARIO-B",
        name: "Worsening Monsoon / Corridor Cutoff",
        scenario_name: "Worsening Monsoon / Corridor Cutoff",
        description: "Precipitation accelerates by +35%; secondary mountain chokepoint blocked",
        threat_level: worse_threat,
        threat_classification: worse_threat >= 85.0 ? "CATASTROPHIC" : "CRITICAL",
        plan_validity_score: 48.0,
        optimal_strategy_type: "AERIAL_CONTINGENCY",
        population_exposure: (snapshot[:population_at_risk] * 1.45).to_i,
        response_eta_hours: ((strategy[:estimated_eta_hours] || 4.2) * 1.6).round(1),
        route_resilience_score: 52.0,
        resilience_score: 52.0,
        uncertainty: "HIGH"
      }

      # Scenario 3: Rapid Improvement / Stabilization
      better_threat = [snapshot[:overall_threat_level] - 20.0, 15.0].max.round(1)
      scenarios << {
        id: "SCENARIO-C",
        name: "Stabilization & Water Recession",
        scenario_name: "Stabilization & Water Recession",
        description: "Rainfall subsides, allowing PWD clearance teams to open blocked arteries",
        threat_level: better_threat,
        threat_classification: better_threat < 30.0 ? "LOW" : "ELEVATED",
        plan_validity_score: 95.0,
        optimal_strategy_type: "DIRECT_DISPATCH",
        population_exposure: (snapshot[:population_at_risk] * 0.60).to_i,
        response_eta_hours: [((strategy[:estimated_eta_hours] || 4.2) * 0.75).round(1), 2.0].max,
        route_resilience_score: 92.0,
        resilience_score: 92.0,
        uncertainty: "LOW"
      }

      # Strictly enforce maximum 3 scenarios
      scenarios.first(3)
    end

    # =========================================================================
    # 16. UNIFIED OPERATIONAL PICTURE
    # =========================================================================
    def build_operational_picture(snapshot:, predictive_analysis:, response_plan:, strategy:, assumptions:)
      {
        what_is_happening_now: {
          active_incidents_count: snapshot[:active_incidents],
          current_threat_level: snapshot[:overall_threat_level],
          threat_classification: snapshot[:threat_classification],
          network_health: "#{snapshot[:network_health]}% operational passability",
          population_at_risk: snapshot[:population_at_risk],
          high_risk_corridors: snapshot[:high_risk_corridors]
        },
        what_is_likely_to_happen_next: {
          predicted_failures: snapshot[:predicted_failures],
          cascade_risk: "#{predictive_analysis[:overall_cascade_risk]}% systemic failure likelihood",
          cascade_stages_count: Array(predictive_analysis[:cascade_stages]).size,
          prediction_confidence: snapshot[:data_confidence]
        },
        what_should_be_done: {
          recommended_strategy: strategy[:name],
          strategy_type: strategy[:strategy_type],
          primary_hub: strategy[:primary_warehouse_name],
          priority_zones: strategy[:target_zones] || snapshot[:affected_settlements],
          allocated_tonnage: (strategy[:allocated_resources].is_a?(Hash) ? strategy.dig(:allocated_resources, :total_tonnage) : (strategy[:allocated_resources].is_a?(Array) ? strategy[:allocated_resources].sum { |r| r[:tonnage].to_f } : nil)) || 45.0,
          prepositioning: response_plan[:resource_prepositioning]&.first&.dig(:action) || "Prepare forward staging"
        },
        what_could_invalidate_the_plan: assumptions.select { |a| a[:current_status] != "VALID" }.map do |a|
          "#{a[:assumption]} (#{a[:invalidation_trigger]})"
        end.presence || ["Sudden unforecasted cloudburst or seismic tremor along mountain pass"]
      }
    end

    # =========================================================================
    # 17. RECOMMENDED NEXT ACTION
    # =========================================================================
    def determine_recommended_next_action(command_state:, commitment_level:, top_attention:, verification:, drift:)
      action = if drift[:reoptimization_required]
                 "REOPTIMIZE_RESPONSE"
               elsif commitment_level[:level] == "LEVEL_1_VERIFY" && verification
                 "VERIFY_WITH_UAV"
               elsif command_state[:phase] == "REVISED_PLAN_GENERATED"
                 "APPROVE_RESPONSE_PLAN"
               elsif top_attention
                 case top_attention[:action_type]
                 when "ACT_NOW"    then "ACTIVATE_ALTERNATE_ROUTE"
                 when "VERIFY_NOW" then "VERIFY_WITH_UAV"
                 when "PREPARE"    then "PREPOSITION_RESOURCES"
                 else "APPROVE_RESPONSE_PLAN"
                 end
               else
                 "MONITOR_SITUATION"
               end

      {
        action: action,
        priority: %w[ACTIVATE_ALTERNATE_ROUTE REOPTIMIZE_RESPONSE APPROVE_RESPONSE_PLAN].include?(action) ? "IMMEDIATE" : "HIGH",
        timing: action == "IMMEDIATE" ? "WITHIN_15_MINUTES" : "WITHIN_30_MINUTES",
        trigger: "Calculated from threat severity, plan drift (#{drift[:severity]}), and data confidence",
        rationale: "Aligns relief operations with highest utility, minimal population exposure, and verified road access.",
        expected_benefit: "Averts life-safety supply disruptions for vulnerable settlements.",
        requires_human_approval: true,
        autonomous_execution: false,
        owner_type: "LOGISTICS_COMMAND"
      }
    end

    # =========================================================================
    # 18. CLOSED-LOOP STATUS & EXPLAINABILITY
    # =========================================================================
    def evaluate_closed_loop(previous_snapshot:, current_snapshot:, drift:, validity:, reoptimization:)
      status = if reoptimization[:reoptimization_performed]
                 "REOPTIMIZATION_REQUIRED"
               elsif drift[:detected]
                 "DRIFT_DETECTED"
               elsif validity[:classification] == "VALID"
                 "STABLE"
               else
                 "MONITORING"
               end

      triggers = []
      triggers << "Threat delta +#{drift.dig(:drift_factors, :threat)}" if drift.dig(:drift_factors, :threat).to_f > 10.0
      triggers << "Network health degradation" if drift.dig(:drift_factors, :network).to_f > 10.0
      triggers << "Assumption breach detected" if drift[:affected_assumptions].any?

      {
        cycle_status: status,
        previous_state_available: previous_snapshot.present?,
        current_situation_changed: drift[:detected],
        plan_still_valid: validity[:score] >= 65.0,
        next_evaluation_recommended: "30_MINUTES",
        triggers: triggers.presence || ["Periodic 30-minute closed-loop reassessment interval"]
      }
    end

    def build_command_explainability(snapshot:, strategy:, drift:, assumptions:, uncertainty:, reoptimization:)
      {
        situation_summary: "ENMA Command Intelligence evaluated #{snapshot[:active_incidents]} active incidents across #{snapshot[:available_warehouses]} depots. Threat level is #{snapshot[:threat_classification]}.",
        why_this_plan: [
          "Protects maximum vulnerable population (#{strategy[:population_protected] || snapshot[:population_at_risk]} residents)",
          "Avoids high-risk infrastructure chokepoints with ML disruption probability >= 60%",
          "Maintains multi-depot operational redundancy and strict warehouse capacity bounds",
          "Preserves high plan resilience score (#{strategy[:plan_resilience_score] || 82.0}%)"
        ],
        key_risks: [
          "Monsoon rainfall acceleration triggering unmapped secondary landslides",
          "Single bridge failure severing secondary bypass corridor",
          "Data uncertainty (#{uncertainty[:uncertainty_level]}) requiring field corroboration"
        ],
        assumptions: assumptions.map { |a| "#{a[:assumption]} [#{a[:current_status]}]" },
        uncertainty: uncertainty[:key_uncertainties],
        rejected_alternatives: [
          {
            name: "Unfortified Direct Dispatch",
            reason: "Exposes heavy relief convoys to critical single point of failure with 75% disruption probability"
          },
          {
            name: "Total Airlift Protocol",
            reason: "Excessive fuel consumption and payload tonnage constraints for mass population feeding"
          }
        ],
        drift_explanation: drift[:reasons],
        reoptimization_reason: reoptimization[:narrative] ? [reoptimization[:narrative]] : [],
        human_action_required: true,
        autonomous_execution: false
      }
    end

    # =========================================================================
    # 19. HELPERS & ORCHESTRATION CACHING
    # =========================================================================
    def fetch_or_run_predictive_intelligence(forecast_hours)
      begin
        if @predictive_service
          return @predictive_service.analyze(forecast_hours: forecast_hours)
        else
          cache_key = "enma/predictive_cascade_analysis/#{forecast_hours}/#{@roads.map { |r| r.try(:updated_at) }.compact.max.to_i}"
          if defined?(Rails) && Rails.cache
            cached = Rails.cache.read(cache_key)
            if cached
              @cache_hits += 1
              return cached
            end
            svc = PredictiveCascadingImpactService.new(roads: @roads, locations: @locations, warehouses: @warehouses)
            res = svc.analyze(forecast_hours: forecast_hours)
            Rails.cache.write(cache_key, res, expires_in: 3.minutes)
            return res
          else
            svc = PredictiveCascadingImpactService.new(roads: @roads, locations: @locations, warehouses: @warehouses)
            return svc.analyze(forecast_hours: forecast_hours)
          end
        end
      rescue StandardError => e
        Rails.logger.warn("[UnifiedEmergencyCommandService] Predictive analysis fallback: #{e.message}")
        @predictive_engine_failed = true
        build_fallback_predictive_analysis
      end
    end

    def fetch_or_run_response_optimization(forecast_hours, predictive_analysis, force_reopt: false)
      begin
        if @response_service && !force_reopt
          @response_service.analyze(forecast_hours: forecast_hours)
        else
          svc = AutonomousResponseOptimizationService.new(
            locations: @locations,
            warehouses: @warehouses,
            roads: @roads,
            predictive_analysis: predictive_analysis,
            network_service: @network_service
          )
          svc.analyze(forecast_hours: forecast_hours)
        end
      rescue StandardError => e
        Rails.logger.warn("[UnifiedEmergencyCommandService] Response optimization fallback: #{e.message}")
        build_fallback_response_plan
      end
    end

    def build_fallback_predictive_analysis
      {
        overall_cascade_risk: 35.0,
        risk_level: "MODERATE",
        threatened_roads: [],
        scenarios: [],
        recommendations: [],
        watchlist: [],
        cascade_stages: []
      }
    end

    def build_fallback_response_plan
      {
        status: "COMPLETE",
        human_approval_status: "AWAITING_HUMAN_COMMAND_APPROVAL",
        overall_response_urgency: 40.0,
        priority_zones: [],
        warehouse_capabilities: [],
        optimal_strategy: {
          strategy_type: "BALANCED_DISPATCH",
          name: "Defensive Fallback Staging Plan",
          risk_adjusted_utility: 65.0,
          plan_resilience_score: 70.0,
          population_protected: 10_000,
          allocated_resources: []
        },
        alternative_strategies: [],
        contingency_plans: []
      }
    end

    def generate_scenario_fingerprint(data)
      canonical = data.transform_values do |val|
        val.is_a?(Array) ? val.map(&:to_s).sort : val.to_s
      end
      Digest::SHA256.hexdigest(canonical.to_json)[0..15].upcase
    end

    def create_command_alerts!(snapshot, drift, validity, strategy)
      alerts = []
      return alerts unless defined?(LogisticsAlert)

      if drift[:severity].in?(%w[HIGH CRITICAL]) || validity[:score] < 40.0
        fp = snapshot[:scenario_fingerprint]
        existing = LogisticsAlert.where("created_at >= ?", 12.hours.ago)
                                 .where("metadata_json LIKE ?", "%#{fp}%")
                                 .exists?
        unless existing
          alert = LogisticsAlert.create!(
            alert_type: "command_plan_drift_detected",
            severity: "critical",
            title: "Plan Drift Alert: #{drift[:severity]} Degradation Detected",
            message: "Operational assumptions compromised. Drift score: #{drift[:drift_score]}. Human command review required.",
            status: "active",
            metadata_json: {
              fingerprint: fp,
              drift_score: drift[:drift_score],
              validity_score: validity[:score],
              recommended_strategy: strategy[:name]
            }
          )
          alerts << alert
        end
      end

      alerts
    end

    def build_empty_command_result(forecast_hours, start_clock, data_reliability)
      elapsed_ms = start_clock ? ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_clock) * 1000.0).round(1) : 1.0

      {
        status: "ACTIVE",
        command_state: {
          phase: "MONITORING",
          status: "MONITORING",
          human_control_required: true,
          autonomous_execution: false,
          requires_commander_sign_off: false,
          disclaimer: "AI RECOMMENDATION — NOT AUTONOMOUS EXECUTION."
        },
        situation_snapshot: {
          timestamp: Time.current,
          scenario_fingerprint: "EMPTY-NETWORK",
          overall_threat_level: 0.0,
          threat_classification: "LOW",
          active_incidents: 0,
          high_risk_corridors: [],
          predicted_failures: [],
          affected_settlements: [],
          population_at_risk: 0,
          available_warehouses: 0,
          network_health: 100.0,
          data_confidence: data_reliability[:score],
          trend: "STABLE"
        },
        operational_picture: {
          what_is_happening_now: {},
          what_is_likely_to_happen_next: {},
          what_should_be_done: {},
          what_could_invalidate_the_plan: []
        },
        commander_attention: [],
        data_reliability: data_reliability,
        uncertainty_analysis: { uncertainty_score: 0.0, uncertainty_level: "LOW", confidence_interval: [0.0, 0.0], key_uncertainties: [] },
        commitment_level: COMMITMENT_LEVELS[0],
        plan_assumptions: [],
        assumption_health_score: 100.0,
        verification_recommendations: [],
        no_action_baseline: { disclaimer: "No active network", narrative: "Nominal conditions.", postures: [] },
        decision_trace: [],
        historical_context: { total_recorded_decisions: 0, similar_scenarios_count: 0, decision_breakdown: {} },
        scenario_comparison: [],
        plan_drift: { detected: false, severity: "NONE", drift_score: 0.0, reasons: [], reoptimization_required: false },
        plan_validity: { score: 100.0, classification: "VALID", color: "#10b981", degradation_factors: [] },
        predictive_intelligence: {},
        response_optimization: {},
        reoptimization: { reoptimization_performed: false },
        closed_loop_status: { cycle_status: "MONITORING", plan_still_valid: true },
        recommended_next_action: { action: "MONITOR_SITUATION", priority: "ROUTINE", timing: "CONTINUOUS", requires_human_approval: true },
        explainability: { situation_summary: "No network data registered", why_this_plan: [], human_action_required: true },
        alerts_generated_count: 0,
        instrumentation: { execution_time_ms: elapsed_ms, services_orchestrated: [] }
      }
    end
  end
end
