# frozen_string_literal: true

module ResQWay
  class PredictiveCascadingImpactService
    EARTH_RADIUS_KM = 6371.0
    MAX_SIMULATION_BUDGET = 6
    DEFAULT_CANDIDATE_LIMIT = 5

    HORIZONS = [3, 12, 24, 72].freeze

    # Risk Level Classification Thresholds
    CASCADE_LEVELS = {
      catastrophic: 85.0,
      critical:     70.0,
      high:         50.0,
      elevated:     30.0
    }.freeze

    # Operational Recommendation Owner Types
    OWNER_TYPES = %w[
      DISASTER_RESPONSE_TEAM
      ROAD_AUTHORITY
      LOGISTICS_COMMAND
      FIELD_VERIFICATION_TEAM
      WEATHER_MONITORING_CELL
      UAV_RECONNAISSANCE_TEAM
    ].freeze

    attr_reader :roads, :locations, :warehouses, :network_service, :simulation_calls, :cache_hits

    def initialize(roads: nil, locations: nil, warehouses: nil, network_service: nil)
      @roads = roads || (defined?(Road) ? Road.all.to_a : [])
      @locations = locations || (defined?(Location) ? Location.all.to_a : [])
      @warehouses = warehouses || (defined?(Warehouse) ? Warehouse.all.to_a : [])
      @network_service = network_service || ResQWay::NetworkConnectivityService.new(
        locations: @locations,
        roads: @roads,
        warehouses: @warehouses
      )
      @simulation_calls = 0
      @cache_hits = 0
    end

    def analyze(forecast_hours: 12, candidate_limit: DEFAULT_CANDIDATE_LIMIT, create_alerts: false)
      start_clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      forecast_hours = forecast_hours.to_i
      forecast_hours = 12 unless HORIZONS.include?(forecast_hours)
      candidate_limit = [[candidate_limit.to_i, 1].max, DEFAULT_CANDIDATE_LIMIT].min

      # Handle empty network edge case gracefully
      if @roads.empty? || @locations.empty?
        return empty_analysis_result(forecast_hours, start_clock)
      end

      # 1. Base network topology & criticality analysis (memoized)
      base_network_analysis = @network_service.analyze(include_criticalities: true)
      critical_roads_map = build_critical_roads_map(base_network_analysis)

      # 2. Road failure forecasting for all operational roads
      threatened_roads = forecast_threatened_roads(critical_roads_map)

      # 3. Overall environmental & operational escalation trend
      trend = calculate_escalation_trend(threatened_roads)

      # 4. Multi-horizon projection scaling & temporal acceleration
      threatened_roads.each do |threat|
        road = @roads.find { |r| r.id == threat[:road_id] }
        threat[:forecast] = compute_horizon_forecasts(
          threat[:failure_probability],
          trend,
          road,
          threat[:primary_incident]
        )
      end

      # 5. Threat Candidate Selection (bounded by candidate_limit <= 5)
      # Rank candidates by Expected Operational Threat (EOT) & Threat Priority
      top_candidates = select_top_candidates(threatened_roads, candidate_limit)

      # 6. Bounded Cascading Scenario Generation (Strict Budget <= 6)
      scenarios = generate_bounded_scenarios(top_candidates, base_network_analysis, trend, forecast_hours)

      # 7. Watchlist floor & classification (prevent low-confidence catastrophic events from disappearing)
      watchlist = extract_watchlist_scenarios(scenarios, threatened_roads)

      # 8. Overall cascade risk and priority aggregation
      top_scenario = scenarios.max_by { |s| s[:expected_operational_threat] || s[:scenario_priority_score] }
      overall_risk = calculate_overall_cascade_risk(threatened_roads, scenarios)
      overall_level = classify_cascade_level(overall_risk)

      # 9. Preemptive Operational Recommendations
      recommendations = compile_consolidated_recommendations(scenarios, top_candidates, trend)

      # 10. Optional Alert Integration (with 24-hour deduplication and EOT + confidence threshold gating)
      generated_alerts = []
      if create_alerts && defined?(LogisticsAlert)
        generated_alerts = create_predictive_alerts!(scenarios, overall_risk)
      end

      # 11. Summary narrative & warnings
      explanations = compile_overall_explanations(threatened_roads, scenarios, trend, overall_risk)
      warnings = compile_overall_warnings(threatened_roads, trend)
      ranking_explanation = build_ranking_explanation(scenarios, threatened_roads)
      projected_impact = compile_projected_impact_summary(scenarios, base_network_analysis)

      elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_clock) * 1000.0).round(1)

      avg_confidence = if threatened_roads.any?
                         (threatened_roads.sum { |r| r[:prediction_confidence] } / threatened_roads.size.to_f).round(1)
                       else
                         100.0
                       end

      total_pop_at_risk = scenarios.map { |s| s.dig(:projected_impact, :affected_population).to_i }.max || 0

      {
        status: "complete",
        generated_at: Time.current,
        forecast_horizon: forecast_hours,
        overall_cascade_risk: overall_risk.round(1),
        risk_level: overall_level[:level],
        risk_color: overall_level[:color],
        risk_badge_class: overall_level[:badge_class],
        trend: trend,
        summary: {
          overall_cascade_risk: overall_risk.round(1),
          risk_level: overall_level[:level],
          prediction_confidence: avg_confidence,
          threatened_population: total_pop_at_risk,
          actionable_scenarios_count: scenarios.count { |s| s[:operational_status] == "ACTIONABLE" },
          verification_watchlist_count: scenarios.count { |s| s[:operational_status] == "NEEDS_VERIFICATION" }
        },
        instrumentation: {
          candidates_evaluated: top_candidates.size,
          simulations_performed: @simulation_calls,
          execution_time_ms: elapsed_ms,
          cache_hits: @cache_hits
        },
        threatened_roads: threatened_roads.sort_by { |r| -r[:expected_operational_threat] },
        top_candidates: top_candidates,
        scenarios: scenarios,
        top_scenario: top_scenario,
        watchlist: watchlist,
        cascade_stages: top_scenario&.dig(:cascade_stages) || [],
        failure_dependency_graph: top_scenario&.dig(:failure_dependency_graph) || {},
        projected_impact: projected_impact,
        recommendations: recommendations,
        alerts_generated_count: generated_alerts.size,
        explanation: explanations,
        warnings: warnings,
        ranking_explanation: ranking_explanation,
        metadata: {
          roads_analyzed: @roads.size,
          scenarios_generated: scenarios.size,
          simulation_calls: @simulation_calls,
          simulation_budget: {
            allowed: MAX_SIMULATION_BUDGET,
            used: @simulation_calls
          },
          bounded: true
        }
      }
    end


    # =========================================================================
    # STEP 1: ROAD FAILURE FORECASTING
    # =========================================================================
    def forecast_threatened_roads(critical_roads_map)
      @roads.map do |road|
        # A. Road Risk (0-100)
        road_risk = extract_road_risk(road)

        # B. ML Disruption Probability (0-100)
        ml_prob = extract_ml_probability(road, fallback: road_risk)

        # C. Incident Signal & Confidence Signal
        incident_info = extract_incident_signals(road)
        incident_signal = incident_info[:incident_signal]
        confidence_signal = incident_info[:confidence_signal]
        primary_incident = incident_info[:primary_incident]

        # D. Weather Escalation (0-100)
        weather_info = extract_weather_escalation(road)
        weather_escalation = weather_info[:weather_signal]

        # Weighted Synthesis (30% Road Risk, 30% ML Prob, 20% Incidents, 15% Weather, 5% Confidence)
        raw_prob = (0.30 * road_risk) +
                   (0.30 * ml_prob) +
                   (0.20 * incident_signal) +
                   (0.15 * weather_escalation) +
                   (0.05 * confidence_signal)

        # Infrastructure Criticality (0-100)
        crit_details = calculate_infrastructure_criticality(road, critical_roads_map)
        criticality_score = crit_details[:score]

        # Route Resilience (0-100)
        route_resilience = evaluate_route_resilience(road)

        # Weighted Synthesis (30% Road Risk, 30% ML Prob, 20% Incidents, 15% Weather, 5% Confidence)
        raw_prob = (0.30 * road_risk) +
                   (0.30 * ml_prob) +
                   (0.20 * incident_signal) +
                   (0.15 * weather_escalation) +
                   (0.05 * confidence_signal)

        failure_probability = raw_prob.clamp(0.0, 100.0).round(1)

        # Concept B: Prediction Confidence (0-100%)
        # "How trustworthy is this prediction?"
        pred_conf = calculate_prediction_confidence(weather_info, ml_prob, primary_incident, road)
        pred_conf_level = classify_prediction_confidence_level(pred_conf)

        # Concept C: Baseline Local Cascading Impact Proxy (0-100)
        resilience_scarcity = [100.0 - route_resilience[:score], 0.0].max
        cascading_impact_proxy = ((0.50 * criticality_score) + (0.30 * resilience_scarcity) + (0.20 * road_risk)).clamp(0.0, 100.0).round(1)

        # Concept D: Operational Urgency (0-100)
        # "How quickly must humans act?"
        operational_urgency = calculate_operational_urgency(
          failure_prob: failure_probability,
          cascade_impact: cascading_impact_proxy,
          route_resilience_score: route_resilience[:score],
          incident_recent: primary_incident.present? && primary_incident.created_at >= 12.hours.ago
        )

        # Expected Operational Threat (EOT): Prioritization Attention Metric
        # EOT = (FailureProbability * CascadingImpact * PredictionConfidence) / 10000.0
        eot = ((failure_probability * cascading_impact_proxy * pred_conf) / 10000.0).clamp(0.0, 100.0).round(1)

        # Threat Priority Ranking Score = robust blend of failure probability, cascading impact proxy, and criticality
        threat_priority = ((0.50 * failure_probability) + (0.30 * cascading_impact_proxy) + (0.20 * criticality_score)).clamp(0.0, 100.0).round(1)

        # Uncertainty Bounds
        uncertainty = calculate_uncertainty_bounds(
          failure_prob: failure_probability,
          pred_conf: pred_conf,
          weather_available: weather_info[:data_available],
          ml_available: road.try(:ml_disruption_probability).present?,
          primary_incident: primary_incident
        )

        # Watchlist Status
        operational_status = if failure_probability >= 50.0 && cascading_impact_proxy >= 60.0 && pred_conf >= 60.0
                               "ACTIONABLE"
                             elsif cascading_impact_proxy >= 60.0 && pred_conf < 60.0
                               "NEEDS_VERIFICATION"
                             else
                               "MONITOR"
                             end

        contributing_signals = build_contributing_signals_list(road_risk, ml_prob, incident_signal, weather_escalation, criticality_score)
        explanations = build_road_explanations(road, failure_probability, road_risk, ml_prob, incident_info, weather_info, criticality_score, pred_conf)
        warnings = build_road_warnings(road, failure_probability, weather_info, incident_info, pred_conf)

        {
          road_id: road.id,
          road_number: road.road_number,
          road_name: road.name,
          state: road.state,
          district: road.try(:district),
          status: road.status,
          failure_probability: failure_probability,
          prediction_confidence: pred_conf,
          prediction_confidence_level: pred_conf_level,
          cascading_impact_proxy: cascading_impact_proxy,
          operational_urgency: operational_urgency,
          expected_operational_threat: eot,
          threat_priority: threat_priority,
          operational_status: operational_status,
          infrastructure_criticality: crit_details,
          criticality_score: criticality_score,
          route_resilience: route_resilience,
          uncertainty: uncertainty,
          primary_incident: primary_incident,
          forecast: {},
          contributing_factors: {
            road_risk: road_risk.round(1),
            ml_probability: ml_prob.round(1),
            incident_signal: incident_signal.round(1),
            weather_escalation: weather_escalation.round(1),
            confidence_signal: confidence_signal.round(1)
          },
          contributing_signals: contributing_signals,
          explanation: explanations,
          warnings: warnings,
          data_availability: {
            weather_available: weather_info[:data_available],
            ml_available: road.try(:ml_disruption_probability).present?,
            incident_present: primary_incident.present?
          }
        }
      end
    end


    # =========================================================================
    # STEP 4: TREND DETECTION LAYER
    # =========================================================================
    def calculate_escalation_trend(threatened_roads = [])
      signals = []
      escalating_points = 0.0

      # 1. Road failure clusters
      high_threat_count = threatened_roads.count { |r| r[:failure_probability] >= 65.0 }
      if high_threat_count >= 3
        escalating_points += 0.35
        signals << "#{high_threat_count} transportation corridors currently exhibit elevated failure probabilities (>= 65%)."
      elsif high_threat_count >= 1
        escalating_points += 0.20
        signals << "#{high_threat_count} key corridor exhibits elevated disruption risk."
      end

      # 2. Critical bridges under threat
      threatened_bridges = threatened_roads.select { |r| r[:criticality_score] >= 75.0 && r[:failure_probability] >= 50.0 }
      if threatened_bridges.any?
        escalating_points += 0.25
        signals << "Single-point-of-failure network bridge corridors (#{threatened_bridges.map { |b| b[:road_number] }.join(', ')}) under active threat."
      end

      # 3. Recent severe incidents
      if defined?(Incident)
        recent_severe = Incident.where(status: %w[reported verified])
                                .where("reported_at >= ?", 12.hours.ago)
                                .where(severity: %w[high critical])
                                .count
        if recent_severe >= 3
          escalating_points += 0.25
          signals << "#{recent_severe} severe or critical incidents logged in the past 12 hours across the regional sector."
        elsif recent_severe >= 1
          escalating_points += 0.15
          signals << "Active emergency incident logged within recent 12-hour window."
        end
      end

      # 4. Regional weather alerts
      if threatened_roads.any? { |r| r.dig(:contributing_factors, :weather_escalation).to_f >= 70.0 }
        escalating_points += 0.20
        signals << "Severe atmospheric precipitation or storm conditions escalating along operational sectors."
      end

      trend_score = escalating_points.clamp(0.0, 1.0).round(2)
      direction = if trend_score >= 0.50
                    "ESCALATING"
                  elsif trend_score >= 0.25
                    "STABLE"
                  else
                    "IMPROVING"
                  end

      signals << "Operational disruption indicators remain stable and within baseline limits." if signals.empty?

      {
        score: trend_score,
        direction: direction,
        signals: signals
      }
    end

    # =========================================================================
    # STEP 2 & 5: MULTI-HORIZON PREDICTIONS
    # =========================================================================
    # =========================================================================
    # STEP 2 & 5: MULTI-HORIZON PREDICTIONS & TEMPORAL ESCALATION
    # =========================================================================
    def compute_horizon_forecasts(base_prob, trend, road = nil, primary_incident = nil)
      direction = trend[:direction]
      weather_improving = direction == "IMPROVING"
      incident_age_hours = primary_incident&.reported_at ? ((Time.current - primary_incident.reported_at) / 3600.0) : 999.0

      forecast = {}
      HORIZONS.each do |h|
        scaled = if weather_improving
                   # Declining trajectory over longer horizons as weather clears
                   decay_factor = Math.exp(-0.02 * h)
                   base_prob * decay_factor
                 elsif direction == "ESCALATING"
                   # Escalating trajectory over time
                   time_log = Math.log((h.to_f / 12.0) + 1.0)
                   base_prob * (1.0 + (0.22 * time_log))
                 else # STABLE
                   time_log = Math.log((h.to_f / 24.0) + 1.0)
                   base_prob * (1.0 + (0.05 * time_log))
                 end

        if incident_age_hours > 18.0 && h >= 24
          scaled *= 0.85
        end

        forecast["#{h}h"] = clamp_probability(scaled)
      end

      p3 = forecast["3h"].to_f
      p72 = forecast["72h"].to_f
      acceleration = ((p72 - p3) / 69.0).round(2)

      forecast.merge(
        "trend" => direction,
        "acceleration" => acceleration
      )
    end

    def clamp_probability(val)
      val.to_f.clamp(0.0, 100.0).round(1)
    end

    # =========================================================================
    # STEP 2B: CONCEPT SEPARATION & OPERATIONAL URGENCY
    # =========================================================================
    def calculate_operational_urgency(failure_prob:, cascade_impact:, route_resilience_score:, incident_recent:)
      resilience_scarcity = [100.0 - route_resilience_score, 0.0].max
      recency_boost = incident_recent ? 15.0 : 0.0

      urgency = (0.35 * failure_prob) +
                (0.35 * cascade_impact) +
                (0.20 * resilience_scarcity) +
                (0.10 * recency_boost)

      urgency.clamp(0.0, 100.0).round(1)
    end

    # =========================================================================
    # STEP 3B: INFRASTRUCTURE CRITICALITY (0 - 100)
    # =========================================================================
    def calculate_infrastructure_criticality(road, critical_roads_map)
      tarjan_score = critical_roads_map[road.id] || 25.0
      is_bridge = tarjan_score >= 60.0

      nearby_locs = @locations.select do |loc|
        loc.latitude.present? && loc.longitude.present? &&
          road_midpoint(road).first.present? &&
          haversine_distance(road_midpoint(road)[0], road_midpoint(road)[1], loc.latitude, loc.longitude) <= 35.0
      end
      nearby_pop = nearby_locs.sum(&:population)
      total_pop = [@locations.sum(&:population), 1].max
      pop_dependency = ((nearby_pop.to_f / total_pop.to_f) * 100.0 * 2.0).clamp(10.0, 100.0).round(1)

      nearby_wh = @warehouses.count do |w|
        w.latitude.present? && w.longitude.present? &&
          road_midpoint(road).first.present? &&
          haversine_distance(road_midpoint(road)[0], road_midpoint(road)[1], w.latitude, w.longitude) <= 45.0
      end
      wh_dependency = [nearby_wh * 30.0, 100.0].min

      strategic_score = if road.road_number.to_s.start_with?("NH")
                          85.0
                        elsif road.road_number.to_s.start_with?("SH")
                          60.0
                        else
                          35.0
                        end

      scarcity = is_bridge ? 90.0 : 35.0

      crit_score = (0.30 * tarjan_score) +
                   (0.25 * pop_dependency) +
                   (0.20 * wh_dependency) +
                   (0.15 * scarcity) +
                   (0.10 * strategic_score)

      score = crit_score.clamp(10.0, 100.0).round(1)

      explanation = if is_bridge
                      "Single Point of Failure (Tarjan Bridge). Serves #{nearby_locs.size} settlements (~#{nearby_pop} population) with zero immediate parallel corridors."
                    elsif score >= 65.0
                      "Primary arterial connector #{road.road_number} with elevated regional logistics and population dependency."
                    else
                      "Secondary or redundant collector corridor with available bypass routing."
                    end

      {
        score: score,
        is_bridge: is_bridge,
        breakdown: {
          bridge_importance: tarjan_score.round(1),
          population_dependency: pop_dependency.round(1),
          warehouse_dependency: wh_dependency.round(1),
          alternative_scarcity: scarcity.round(1),
          strategic_classification: strategic_score.round(1)
        },
        explanation: explanation
      }
    end

    # =========================================================================
    # STEP 4B: ROUTE RESILIENCE EVALUATION
    # =========================================================================
    def evaluate_route_resilience(road)
      if @network_service.respond_to?(:alternative_route_analysis)
        res = @network_service.alternative_route_analysis(road.id)
        if res
          @cache_hits += 1
          return {
            score: res[:resilience_score],
            category: res[:resilience_category],
            detour_penalty_km: res[:detour_penalty_km],
            detour_ratio: res[:detour_ratio],
            has_alternative: res[:has_alternative],
            status_label: res[:status_label]
          }
        end
      end

      {
        score: 75.0,
        category: "MINOR_DETOUR",
        detour_penalty_km: 15.0,
        detour_ratio: 18.0,
        has_alternative: true,
        status_label: "Minor Detour (+15.0 km / +18.0%)"
      }
    end

    # =========================================================================
    # STEP 5B: UNCERTAINTY BOUNDS & MARGIN COMPUTATION
    # =========================================================================
    def calculate_uncertainty_bounds(failure_prob:, pred_conf:, weather_available:, ml_available:, primary_incident:)
      margin = if pred_conf >= 85.0
                 4.0
               elsif pred_conf >= 70.0
                 7.0
               elsif pred_conf >= 55.0
                 11.0
               else
                 16.0
               end

      margin += 3.0 unless weather_available
      margin += 2.0 unless ml_available

      margin = margin.clamp(3.0, 22.0).round(1)

      low_bound = [failure_prob - margin, 0.0].max.round(1)
      high_bound = [failure_prob + margin, 100.0].min.round(1)

      factors = []
      factors << (weather_available ? "Live meteorological telemetry corroborating" : "Weather telemetry offline (using terrain baseline)")
      factors << (ml_available ? "ML XGBoost model active" : "ML model offline (relying on empirical terrain vulnerability)")
      if primary_incident
        factors << "Field report corroboration (#{primary_incident.confidence_level} confidence)"
      else
        factors << "No active incident filed; baseline environmental estimation"
      end

      {
        central_estimate: failure_prob,
        lower_bound: low_bound,
        upper_bound: high_bound,
        margin: margin,
        formatted_range: "#{low_bound}–#{high_bound}%",
        confidence: pred_conf,
        factors: factors
      }
    end

    # =========================================================================
    # STEP 3 & 7: THREAT CANDIDATE SELECTION & BOUNDED SCENARIOS
    # =========================================================================
    def select_top_candidates(threatened_roads, candidate_limit)
      threatened_roads.sort_by { |r| -r[:expected_operational_threat] }.first(candidate_limit)
    end

    def generate_bounded_scenarios(candidates, base_network_analysis, trend, forecast_hours)
      scenarios = []
      return scenarios if candidates.empty? || @simulation_calls >= MAX_SIMULATION_BUDGET

      # -----------------------------------------------------------------------
      # Scenario Type A: Single Road Failures (Up to top 3)
      # -----------------------------------------------------------------------
      candidates_to_simulate = candidates.select { |c| c[:failure_probability] >= 15.0 || c[:cascading_impact_proxy] >= 50.0 }
      candidates_to_simulate = candidates.first(1) if candidates_to_simulate.empty?

      candidates_to_simulate.first(3).each do |cand|
        break if @simulation_calls >= MAX_SIMULATION_BUDGET

        road = @roads.find { |r| r.id == cand[:road_id] }
        next unless road

        sim_result = run_guarded_network_simulation([road.id])
        next unless sim_result

        scen = build_scenario_record(
          scenario_id: "SCEN-S#{scenarios.size + 1}",
          scenario_type: "single_road",
          name: "Projected Disruption of #{road.road_number} (#{road.name})",
          roads: [cand],
          sim_result: sim_result,
          trend: trend,
          forecast_hours: forecast_hours
        )
        scenarios << scen
      end

      # -----------------------------------------------------------------------
      # Scenario Type B: Correlated Pair Failures (Up to 2 scenarios)
      # Only simulate if CorrelationScore >= 50.0
      # -----------------------------------------------------------------------
      pair_count = 0
      candidates.combination(2) do |cand1, cand2|
        break if pair_count >= 2 || @simulation_calls >= MAX_SIMULATION_BUDGET

        road1 = @roads.find { |r| r.id == cand1[:road_id] }
        road2 = @roads.find { |r| r.id == cand2[:road_id] }
        next unless road1 && road2

        corr = calculate_correlation(road1, road2, cand1, cand2)
        if corr[:correlated]
          pair_count += 1
          sim_result = run_guarded_network_simulation([road1.id, road2.id])
          next unless sim_result

          scen = build_scenario_record(
            scenario_id: "SCEN-P#{pair_count}",
            scenario_type: "pair_road",
            name: "Compound Disruption: #{road1.road_number} & #{road2.road_number}",
            roads: [cand1, cand2],
            sim_result: sim_result,
            trend: trend,
            forecast_hours: forecast_hours,
            correlation: corr
          )
          scenarios << scen
        end
      end

      # -----------------------------------------------------------------------
      # Scenario Type C: Critical Cascade (At most 1 scenario)
      # -----------------------------------------------------------------------
      if scenarios.none? { |s| s[:scenario_type] == "critical_cascade" } &&
         @simulation_calls < MAX_SIMULATION_BUDGET
        bridge_cand = candidates.find { |c| c[:criticality_score] >= 70.0 }
        if bridge_cand
          bridge_road = @roads.find { |r| r.id == bridge_cand[:road_id] }
          adjacent_cand = candidates.find do |c|
            c[:road_id] != bridge_cand[:road_id] &&
              roads_adjacent?(bridge_road, @roads.find { |r| r.id == c[:road_id] })
          end

          if bridge_road && adjacent_cand
            adj_road = @roads.find { |r| r.id == adjacent_cand[:road_id] }
            sim_result = run_guarded_network_simulation([bridge_road.id, adj_road.id])
            if sim_result
              scenarios << build_scenario_record(
                scenario_id: "SCEN-CC1",
                scenario_type: "critical_cascade",
                name: "Critical Corridor Collapse: #{bridge_road.road_number} & #{adj_road.road_number}",
                roads: [bridge_cand, adjacent_cand],
                sim_result: sim_result,
                trend: trend,
                forecast_hours: forecast_hours
              )
            end
          end
        end
      end

      scenarios.sort_by { |s| -s[:expected_operational_threat] }
    end

    def run_guarded_network_simulation(road_ids)
      return nil if @simulation_calls >= MAX_SIMULATION_BUDGET

      @simulation_calls += 1
      @network_service.simulate_multiple_road_closures(road_ids, status: "blocked")
    rescue StandardError => e
      Rails.logger.warn("[PredictiveCascadingImpactService] Simulation failed: #{e.message}")
      nil
    end

    # =========================================================================
    # STEP 9: CORRELATED FAILURE DETECTION
    # =========================================================================
    def calculate_correlation(road1, road2, cand1 = nil, cand2 = nil)
      return { correlated: false, score: 0.0, reasons: [] } if road1.id == road2.id

      score = 0.0
      reasons = []

      # 1. Shared Network Node (+30)
      if roads_share_endpoint?(road1, road2)
        score += 30.0
        reasons << "Corridors share a common geographical junction node"
      end

      # 2. Same District / State (+15)
      if road1.state.present? && road1.state == road2.state
        score += 10.0
        reasons << "Co-located within same regional administrative zone (#{road1.state})"
        if road1.try(:district).present? && road1.district == road2.try(:district)
          score += 5.0
          reasons << "Co-located within identical district (#{road1.district})"
        end
      end

      # 3. Shared Weather System (Midpoint Distance <= 50km) (+20)
      dist = road_midpoint_distance(road1, road2)
      if dist && dist <= 50.0
        score += 20.0
        reasons << "Separated by only #{dist.round(1)} km; exposed to identical meteorological storm cell"
      end

      # 4. Elevated Probabilities for Both (+15)
      p1 = cand1 ? cand1[:failure_probability] : road1.risk_score.to_f
      p2 = cand2 ? cand2[:failure_probability] : road2.risk_score.to_f
      if p1 >= 35.0 && p2 >= 35.0
        score += 15.0
        reasons << "Both transport corridors concurrently exhibit elevated disruption risk (> 35%)"
      end

      # 5. Alternative Route Interdependence (+25)
      if cand1 && cand1.dig(:route_resilience, :has_alternative) && dist && dist <= 80.0
        score += 20.0
        reasons << "#{road2.road_number} acts as a primary bypass corridor if #{road1.road_number} fails"
      end

      total_score = score.clamp(0.0, 100.0).round(1)
      is_correlated = total_score >= 50.0

      {
        correlated: is_correlated,
        score: total_score,
        reasons: reasons
      }
    end

    def roads_correlated?(road1, road2)
      calculate_correlation(road1, road2)[:correlated]
    end

    def build_causal_chain(roads:, sim_result:, new_iso_settlements:, affected_pop:, affected_wh:, operational_action:, trend:)
      road_names = roads.map { |r| r[:road_number] || r.try(:road_number) }.compact.join(", ")
      chain = []
      chain << "Initial Trigger: Severe environmental and topological stressors escalate Failure probability for #{road_names} to critical levels."
      if new_iso_settlements.any?
        settle_names = new_iso_settlements.first(3).map { |s| s.is_a?(Hash) ? s[:name] : s.to_s }.join(", ")
        chain << "Local Isolation: Inaccessibility of #{road_names} immediately cuts off #{new_iso_settlements.size} settlements (#{settle_names}) with an estimated #{affected_pop} population."
      else
        chain << "Local Divergence: Traffic shifts to secondary alternative corridors, increasing transit duration and network stress."
      end
      if affected_wh.any?
        wh_names = affected_wh.first(2).map { |w| w.is_a?(Hash) ? w[:name] : w.to_s }.join(", ")
        chain << "Supply Disruption: Logistics hub isolation severing relief supply from #{wh_names} to downstream districts."
      else
        chain << "Systemic Strain: Overall network health degrades, shifting bottleneck load onto adjoining secondary arteries."
      end
      chain << "Operational Mandate: #{operational_action.to_s.humanize} initiated to mitigate cascading failure under #{trend[:direction]} trend."
      chain
    end

    # =========================================================================
    # STEP 10: SCENARIO RECORD BUILDER & 5-STAGE CASCADE DEPTH
    # =========================================================================
    def build_scenario_record(scenario_id:, scenario_type:, name:, roads:, sim_result:, trend:, forecast_hours:, correlation: nil)
      primary_cand = roads.first
      road_ids = roads.map { |r| r[:road_id] }

      failure_prob = if roads.size == 1
                       primary_cand[:failure_probability]
                     else
                       p1 = roads.first[:failure_probability] / 100.0
                       p2 = roads.second[:failure_probability] / 100.0
                       ((1.0 - ((1.0 - p1) * (1.0 - p2))) * 100.0).clamp(10.0, 100.0).round(1)
                     end

      pred_conf = (roads.sum { |r| r[:prediction_confidence] } / roads.size.to_f).round(1)
      pred_conf_level = classify_prediction_confidence_level(pred_conf)

      new_iso_settlements = sim_result[:newly_isolated_settlements] || []
      new_iso_count = new_iso_settlements.size

      affected_pop = new_iso_settlements.sum do |sname|
        loc = @locations.find { |l| l.name == sname }
        loc&.population.to_i
      end

      total_pop = @locations.sum { |l| l.population.to_i }
      total_pop = 1 if total_pop <= 0

      affected_wh = sim_result[:affected_warehouses] || []
      affected_wh_count = sim_result[:affected_warehouses_count].to_i
      total_wh = @warehouses.count { |w| w.operational_status == "OPERATIONAL" }
      total_wh = @warehouses.size if total_wh <= 0

      route_resilience = primary_cand[:route_resilience] || { score: 60.0, category: "LONG_OR_RISKY_DETOUR" }

      pop_ratio = (affected_pop.to_f / total_pop.to_f).clamp(0.0, 1.0)
      count_ratio = (new_iso_count.to_f / [@locations.size, 1].max).clamp(0.0, 1.0)
      pop_iso_score = ([pop_ratio * 100.0 * 2.5, count_ratio * 100.0].max).clamp(0.0, 100.0)

      health_drop = [100.0 - sim_result[:network_health_score].to_f, 0.0].max
      fragmentation_score = health_drop.clamp(0.0, 100.0)

      wh_score = if total_wh.positive?
                   ((affected_wh_count.to_f / total_wh.to_f) * 100.0).clamp(0.0, 100.0)
                 else
                   0.0
                 end

      crit_infra_score = [
        (affected_wh_count * 30.0) + (sim_result[:criticality_score].to_f * 0.5),
        100.0
      ].min.clamp(0.0, 100.0)

      route_scarcity_score = [100.0 - route_resilience[:score], 0.0].max.clamp(0.0, 100.0)

      cascade_score = (
        (0.30 * pop_iso_score) +
        (0.25 * fragmentation_score) +
        (0.20 * wh_score) +
        (0.15 * crit_infra_score) +
        (0.10 * route_scarcity_score)
      ).clamp(0.0, 100.0).round(1)

      impact_classification = classify_cascade_level(cascade_score)

      # Expected Operational Threat (EOT): Prioritization Attention Metric
      # EOT = (FailureProbability * CascadingImpact * PredictionConfidence) / 10000.0
      eot = ((failure_prob.to_f * cascade_score.to_f * pred_conf.to_f) / 10000.0).clamp(0.0, 100.0).round(1)

      operational_urgency = calculate_operational_urgency(
        failure_prob: failure_prob,
        cascade_impact: cascade_score,
        route_resilience_score: route_resilience[:score],
        incident_recent: trend[:direction] == "ESCALATING"
      )

      operational_status = if failure_prob >= 50.0 && cascade_score >= 60.0 && pred_conf >= 60.0
                             "ACTIONABLE"
                           elsif cascade_score >= 60.0 && pred_conf < 60.0
                             "NEEDS_VERIFICATION"
                           else
                             "MONITOR"
                           end

      matrix_action = classify_matrix_action(failure_prob, cascade_score)

      cascade_stages = build_cascade_stages(
        roads: roads,
        sim_result: sim_result,
        new_iso_settlements: new_iso_settlements,
        affected_pop: affected_pop,
        affected_wh: affected_wh,
        failure_prob: failure_prob,
        health_drop: health_drop,
        route_resilience: route_resilience
      )

      dependency_graph = build_failure_dependency_graph(
        roads: roads,
        new_iso_settlements: new_iso_settlements,
        affected_wh: affected_wh,
        route_resilience: route_resilience
      )

      counterfactual = simulate_counterfactual_intervention(
        roads: roads,
        new_iso_settlements: new_iso_settlements,
        affected_pop: affected_pop,
        affected_wh: affected_wh,
        sim_result: sim_result,
        cascade_score: cascade_score,
        route_resilience: route_resilience
      )

      recs = generate_structured_recommendations(
        roads: roads,
        new_iso_settlements: new_iso_settlements,
        affected_pop: affected_pop,
        affected_wh: affected_wh,
        sim_result: sim_result,
        cascade_score: cascade_score,
        eot: eot,
        failure_prob: failure_prob,
        pred_conf: pred_conf,
        operational_status: operational_status,
        route_resilience: route_resilience
      )

      causal_chain = build_causal_chain(
        roads: roads,
        sim_result: sim_result,
        new_iso_settlements: new_iso_settlements,
        affected_pop: affected_pop,
        affected_wh: affected_wh,
        operational_action: matrix_action,
        trend: trend
      )

      uncertainty = calculate_uncertainty_bounds(
        failure_prob: failure_prob,
        pred_conf: pred_conf,
        weather_available: roads.all? { |r| r.dig(:data_availability, :weather_available) != false },
        ml_available: roads.all? { |r| r.dig(:data_availability, :ml_available) != false },
        primary_incident: roads.first[:primary_incident]
      )

      {
        scenario_id: scenario_id,
        scenario_type: scenario_type,
        name: name,
        road_ids: road_ids,
        roads: roads.map { |r| { id: r[:road_id], number: r[:road_number], name: r[:road_name], failure_probability: r[:failure_probability] } },
        failure_probability: failure_prob,
        prediction_confidence: pred_conf,
        prediction_confidence_level: pred_conf_level,
        cascade_score: cascade_score,
        impact_level: impact_classification[:level],
        risk_color: impact_classification[:color],
        risk_badge_class: impact_classification[:badge_class],
        expected_operational_threat: eot,
        scenario_priority_score: eot,
        operational_urgency: operational_urgency,
        operational_status: operational_status,
        operational_category: matrix_action,
        correlation: correlation,
        infrastructure_criticality: primary_cand[:infrastructure_criticality],
        route_resilience: route_resilience,
        uncertainty: uncertainty,
        cascade_stages: cascade_stages,
        cascade_chain: causal_chain,
        causal_chain: causal_chain,
        failure_dependency_graph: dependency_graph,
        counterfactual_action: counterfactual,
        projected_impact: {
          newly_isolated_settlements: new_iso_settlements,
          newly_isolated_count: new_iso_count,
          total_isolated_settlements: sim_result[:total_isolated_settlements].to_i,
          affected_population: affected_pop,
          total_regional_population: total_pop,
          affected_warehouses: affected_wh,
          affected_warehouses_count: affected_wh_count,
          network_health_score: sim_result[:network_health_score].to_f.round(1),
          connected_settlements_count: sim_result[:post_connected_settlements].to_i,
          alternative_access: sim_result[:alternative_access]
        },
        impact_breakdown: {
          population_isolation: pop_iso_score.round(1),
          network_fragmentation: fragmentation_score.round(1),
          warehouse_disconnection: wh_score.round(1),
          critical_infrastructure: crit_infra_score.round(1),
          route_burden: route_scarcity_score.round(1)
        },
        recommendations: recs
      }
    end

    # =========================================================================
    # STEP 11: 5-STAGE CASCADE PROPAGATION DEPTH
    # =========================================================================
    def build_cascade_stages(roads:, sim_result:, new_iso_settlements:, affected_pop:, affected_wh:, failure_prob:, health_drop:, route_resilience:)
      road_names = roads.map { |r| r[:road_name] }.join(" and ")

      [
        {
          stage: 1,
          name: "Infrastructure Failure",
          event: "Structural obstruction / roadbed destabilization along #{road_names}",
          severity: failure_prob,
          unit: "% failure probability"
        },
        {
          stage: 2,
          name: "Transportation Disruption",
          event: "Primary transportation corridor disconnected from regional arterial network",
          severity: health_drop.round(1),
          unit: "network health drop points"
        },
        {
          stage: 3,
          name: "Settlement Isolation",
          event: "#{new_iso_settlements.size} habitation(s) lose direct passable overland connectivity",
          affected_population: affected_pop,
          settlements: new_iso_settlements
        },
        {
          stage: 4,
          name: "Supply Chain Disruption",
          event: "#{affected_wh.size} relief warehouse hub(s) severed from downstream distribution convoys",
          affected_warehouses: affected_wh,
          loss_type: "Logistics replenishment deficit"
        },
        {
          stage: 5,
          name: "Emergency Response Degradation",
          event: "First responder and disaster dispatch transit times elongate by #{route_resilience[:detour_ratio] || 45}%",
          route_resilience: route_resilience[:score],
          status: route_resilience[:status_label]
        }
      ]
    end

    # =========================================================================
    # STEP 12: FAILURE DEPENDENCY GRAPH (DIRECTED CAUSAL DAG)
    # =========================================================================
    def build_failure_dependency_graph(roads:, new_iso_settlements:, affected_wh:, route_resilience:)
      primary = roads.first
      rname = primary[:road_number] || primary[:road_name]

      nodes = [
        { id: "hazard", label: "Environmental Hazard / Slope Strain", type: "hazard" },
        { id: "physical_failure", label: "#{rname} Physical Failure", type: "infrastructure" },
        { id: "corridor_loss", label: "Primary Corridor Severed", type: "transport" },
        { id: "traffic_shift", label: "Traffic Shift to Secondary Bypass", type: "traffic" },
        { id: "route_strain", label: "Alternative Route Detour (+#{route_resilience[:detour_penalty_km] || 25}km)", type: "route" }
      ]

      edges = [
        { from: "hazard", to: "physical_failure" },
        { from: "physical_failure", to: "corridor_loss" },
        { from: "corridor_loss", to: "traffic_shift" },
        { from: "traffic_shift", to: "route_strain" }
      ]

      if affected_wh.any?
        nodes << { id: "depot_severed", label: "#{affected_wh.first} Cut Off", type: "logistics" }
        edges << { from: "corridor_loss", to: "depot_severed" }
      end

      if new_iso_settlements.any?
        nodes << { id: "habitations_isolated", label: "#{new_iso_settlements.first} Habitation Isolated", type: "societal" }
        edges << { from: "corridor_loss", to: "habitations_isolated" }
      end

      { nodes: nodes, edges: edges }
    end

    # =========================================================================
    # STEP 13: COUNTERFACTUAL INTERVENTION SIMULATION
    # =========================================================================
    def simulate_counterfactual_intervention(roads:, new_iso_settlements:, affected_pop:, affected_wh:, sim_result:, cascade_score:, route_resilience:)
      primary = roads.first
      rname = primary[:road_number] || primary[:road_name]

      if new_iso_settlements.any? && affected_pop.positive?
        est_reduction = 42.0
        {
          recommended_intervention: "PREPOSITION_RELIEF_SUPPLIES",
          action_type: "PREPOSITION_SUPPLIES",
          expected_risk_reduction: est_reduction,
          affected_metric: "POPULATION_SUPPLY_DISRUPTION_RISK",
          baseline_metric_value: affected_pop,
          post_intervention_metric_value: (affected_pop * (1.0 - (est_reduction / 100.0))).round,
          rationale: "Pre-positioning essential relief rations and medicine at #{new_iso_settlements.first} reduces population supply disruption risk by ~42% even if #{rname} suffers complete physical failure.",
          is_estimated: true,
          simulated: true
        }
      elsif affected_wh.any?
        est_reduction = 38.0
        {
          recommended_intervention: "ACTIVATE_ALTERNATE_WAREHOUSE",
          action_type: "ACTIVATE_STANDBY_DEPOT",
          expected_risk_reduction: est_reduction,
          affected_metric: "RELIEF_DEPOT_DEFICIT",
          baseline_metric_value: 100.0,
          post_intervention_metric_value: 62.0,
          rationale: "Activating adjacent regional standby depots mitigates #{affected_wh.first} isolation, preserving ~62% of sector distribution throughput.",
          is_estimated: true,
          simulated: true
        }
      elsif route_resilience[:has_alternative]
        est_reduction = 28.0
        {
          recommended_intervention: "REROUTE_SUPPLY_CONVOYS",
          action_type: "PREEMPTIVE_REROUTING",
          expected_risk_reduction: est_reduction,
          affected_metric: "TRANSIT_BOTTLENECK_DELAY",
          baseline_metric_value: route_resilience[:detour_ratio] || 50.0,
          post_intervention_metric_value: ((route_resilience[:detour_ratio] || 50.0) * 0.72).round(1),
          rationale: "Preemptively diverting non-emergency convoys onto #{route_resilience[:status_label]} avoids catastrophic convoy gridlock before corridor closure.",
          is_estimated: true,
          simulated: true
        }
      else
        est_reduction = 35.0
        {
          recommended_intervention: "DEPLOY_ENGINEERING_INSPECTION",
          action_type: "STRUCTURAL_REINFORCEMENT",
          expected_risk_reduction: est_reduction,
          affected_metric: "CORRIDOR_FAILURE_PROBABILITY",
          baseline_metric_value: primary[:failure_probability],
          post_intervention_metric_value: (primary[:failure_probability] * 0.65).round(1),
          rationale: "Deploying rapid road clearance and slope drainage crews to #{rname} reduces corridor failure probability by an estimated ~35%.",
          is_estimated: true,
          simulated: true
        }
      end
    end

    # =========================================================================
    # STEP 14: STRUCTURED OPERATIONAL RECOMMENDATION PROTOCOL
    # =========================================================================
    def generate_structured_recommendations(roads:, new_iso_settlements:, affected_pop:, affected_wh:, sim_result:, cascade_score:, eot:, failure_prob:, pred_conf:, operational_status:, route_resilience:)
      recs = []
      primary = roads.first
      rname = roads.map { |r| r[:road_name] }.join(" and ")

      if operational_status == "NEEDS_VERIFICATION" || pred_conf < 60.0
        recs << build_rec_item(
          action: "DEPLOY_UAV_RECONNAISSANCE",
          priority: "HIGH",
          timing: "Within 2 hours",
          location: "#{rname} critical sector",
          trigger: "High potential cascading impact (#{cascade_score}/100) with uncorroborated telemetry (#{pred_conf}% confidence)",
          rationale: "Immediate visual confirmation required before issuing full regional road closure or rerouting multi-ton supply convoys.",
          expected_benefit: "Resolves evidence ambiguity and prevents unnecessary freight diversion.",
          owner_type: "UAV_RECONNAISSANCE_TEAM",
          title: "Deploy UAV Aerial Reconnaissance"
        )
      end

      if new_iso_settlements.any? || affected_wh.any?
        loc_target = new_iso_settlements.first
        loc_name = loc_target.is_a?(Hash) ? loc_target[:name] : loc_target.to_s
        recs << build_rec_item(
          action: "PREPOSITION_RELIEF_SUPPLIES",
          priority: failure_prob >= 60.0 ? "CRITICAL" : "HIGH",
          timing: "Within 4–6 hours",
          location: loc_name.presence || "#{rname} forward staging outpost",
          trigger: "Expected Operational Threat score (#{eot}/100) with projected habitation isolation",
          rationale: "Projected failure of #{rname} will disconnect habitations/depots. Staging relief reserves buffers against prolonged overland cutoff.",
          expected_benefit: "Guarantees 7-day food and medical self-sufficiency during initial emergency response.",
          owner_type: "LOGISTICS_COMMAND",
          title: "Preposition Emergency Food & Medical Stocks"
        )
      end

      if route_resilience[:has_alternative] && failure_prob >= 50.0
        recs << build_rec_item(
          action: "ACTIVATE_ALTERNATIVE_ROUTE",
          priority: failure_prob >= 70.0 ? "CRITICAL" : "HIGH",
          timing: "Immediately upon failure probability exceeding 60%",
          location: "Regional bypass corridor (#{route_resilience[:status_label]})",
          trigger: "Failure probability reaches #{failure_prob}%",
          rationale: "Preemptively re-routing traffic prevents freight convoys and ambulances from becoming trapped in mountain chokepoints.",
          expected_benefit: "Maintains supply chain continuity with estimated #{route_resilience[:detour_penalty_km]} km detour burden.",
          owner_type: "ROAD_AUTHORITY",
          title: "Activate Alternate Transport Corridor"
        )
      end

      if roads.any? { |r| r[:criticality_score] >= 65.0 }
        recs << build_rec_item(
          action: "DEPLOY_FIELD_INSPECTION",
          priority: "HIGH",
          timing: "Next 3 hours",
          location: "#{primary[:road_name]} structural bridge / culvert choke-points",
          trigger: "Corridor criticality #{primary[:criticality_score]}/100 with elevated ground failure probability",
          rationale: "Single-point-of-failure infrastructure requires immediate physical assessment of slope stability and culvert debris.",
          expected_benefit: "Early preventative clearing can avert uncontrolled corridor collapse.",
          owner_type: "FIELD_VERIFICATION_TEAM",
          title: "Field Engineering Inspection"
        )
      end

      recs << build_rec_item(
        action: "MONITOR_WEATHER_ESCALATION",
        priority: "MEDIUM",
        timing: "Continuous (30-minute polling cycles)",
        location: "#{primary[:road_name]} meteorological catchment area",
        trigger: "Active weather trend indicators driving failure probability escalation",
        rationale: "Sustained monsoon precipitation increases pore water pressure and reduces shear strength along vulnerable road cuts.",
        expected_benefit: "Provides 2-4 hour early warning prior to major slope mobilization.",
        owner_type: "WEATHER_MONITORING_CELL",
        title: "Monitor Catchment Weather Dynamics"
      )

      recs
    end

    def build_rec_item(action:, priority:, timing:, location:, trigger:, rationale:, expected_benefit:, owner_type:, title:)
      p_norm = case priority.to_s.upcase
               when "IMMEDIATE" then "CRITICAL"
               when "URGENT" then "HIGH"
               when "CRITICAL", "HIGH", "MEDIUM", "LOW" then priority.to_s.upcase
               else "MEDIUM"
               end

      {
        action: action,
        priority: p_norm,
        timing: timing,
        when: timing,
        timeframe: timing,
        location: location,
        where: location,
        trigger: trigger,
        rationale: rationale,
        why: rationale,
        expected_benefit: expected_benefit,
        owner_type: owner_type,
        title: title,
        counterfactual_simulation: expected_benefit,
        simulated_risk_reduction_pct: p_norm == "CRITICAL" ? 45.0 : (p_norm == "HIGH" ? 30.0 : 15.0)
      }
    end

    # =========================================================================
    # STEP 15: RANKING EXPLANATION & WATCHLIST EXTRACTION
    # =========================================================================
    def build_ranking_explanation(scenarios, threatened_roads)
      return "No active scenarios to rank." if scenarios.empty?

      top = scenarios.first
      second = scenarios[1]

      if second
        eot1 = top[:expected_operational_threat]
        eot2 = second[:expected_operational_threat]
        p1 = top[:failure_probability]
        p2 = second[:failure_probability]
        i1 = top[:cascade_score]
        i2 = second[:cascade_score]
        c1 = top[:prediction_confidence]
        c2 = second[:prediction_confidence]

        "#{top[:name]} is ranked as #1 Operational Priority (EOT: #{eot1}/100) above #{second[:name]} (EOT: #{eot2}/100). " \
        "While #{p1 >= p2 ? "#{top[:name]} has higher failure probability (#{p1}% vs #{p2}%)" : "#{second[:name]} has higher failure probability (#{p2}% vs #{p1}%)"}, " \
        "#{top[:name]} commands greater operational attention due to #{i1 >= i2 ? "superior cascading impact (#{i1} vs #{i2})" : "higher prediction confidence (#{c1}% vs #{c2}%) and route vulnerability"}."
      else
        "#{top[:name]} commands primary operational attention with Expected Operational Threat #{top[:expected_operational_threat]}/100 based on #{top[:failure_probability]}% failure probability and #{top[:cascade_score]}/100 cascading impact."
      end
    end

    def extract_watchlist_scenarios(scenarios, threatened_roads)
      watchlist = []

      scenarios.select { |s| s[:operational_status] == "NEEDS_VERIFICATION" }.each do |s|
        watchlist << {
          id: s[:scenario_id],
          name: s[:name],
          type: "NEEDS_VERIFICATION",
          reason: "High Cascading Impact (#{s[:cascade_score]}/100) with unverified confidence (#{s[:prediction_confidence]}%). UAV / ground patrol dispatched.",
          cascade_score: s[:cascade_score],
          failure_probability: s[:failure_probability],
          prediction_confidence: s[:prediction_confidence]
        }
      end

      threatened_roads.select { |r| r[:cascading_impact_proxy] >= 65.0 && r[:prediction_confidence] < 60.0 }.each do |r|
        watchlist << {
          id: "ROAD-#{r[:road_id]}",
          name: "#{r[:road_number]} (#{r[:road_name]})",
          type: "STRATEGIC_WATCH",
          reason: "High infrastructure criticality (#{r[:criticality_score]}/100) with uncorroborated telemetry (#{r[:prediction_confidence]}% confidence).",
          cascade_score: r[:cascading_impact_proxy],
          failure_probability: r[:failure_probability],
          prediction_confidence: r[:prediction_confidence]
        }
      end

      watchlist.uniq { |w| w[:name] }
    end



    # =========================================================================
    # STEP 9: ALERT INTEGRATION & 24-HOUR DEDUPLICATION
    # =========================================================================
    def create_predictive_alerts!(scenarios, overall_risk)
      created_alerts = []
      now = Time.current
      cutoff = 24.hours.ago

      scenarios.each do |scen|
        road_id = scen[:road_ids].first
        road = @roads.find { |r| r.id == road_id }
        next unless road

        alert_type = if scen[:scenario_priority_score] >= 70.0 && %w[CRITICAL CATASTROPHIC].include?(scen[:impact_level])
                       "predictive_cascading_failure"
                     elsif scen[:failure_probability] >= 55.0
                       "cascading_risk_warning"
                     else
                       nil
                     end

        next unless alert_type

        # 24-hour deduplication check
        existing_alert = LogisticsAlert.where(alert_type: alert_type, status: "active")
                                       .where("created_at >= ?", cutoff)
                                       .where("title LIKE ?", "%#{road.road_number}%")
                                       .first

        next if existing_alert

        severity = (alert_type == "predictive_cascading_failure") ? "critical" : "high"
        title = "Predictive Alert: #{road.road_number} — #{scen[:impact_level]} Cascading Risk"
        message = "#{scen[:name]}: Failure probability #{scen[:failure_probability]}%, projected impact score #{scen[:cascade_score]}/100. Action: #{scen[:operational_category]}."

        alert = LogisticsAlert.create!(
          alert_type: alert_type,
          severity: severity,
          title: title,
          message: message,
          status: "active",
          metadata_json: {
            road_id: road.id,
            road_number: road.road_number,
            scenario_id: scen[:scenario_id],
            failure_probability: scen[:failure_probability],
            cascade_score: scen[:cascade_score],
            priority_score: scen[:scenario_priority_score],
            action: scen[:operational_category]
          }
        )
        created_alerts << alert
      rescue StandardError => e
        Rails.logger.warn("[PredictiveCascadingImpactService] Alert creation failed: #{e.message}")
      end

      created_alerts
    end

    def classify_cascade_level(score)
      s = score.to_f
      if s >= 80.0
        { level: "CATASTROPHIC", color: "#dc2626", badge_class: "bg-red-500/15 text-red-600 dark:text-red-400 border-red-500/30" }
      elsif s >= 65.0
        { level: "CRITICAL", color: "#ea580c", badge_class: "bg-orange-500/15 text-orange-600 dark:text-orange-400 border-orange-500/30" }
      elsif s >= 45.0
        { level: "HIGH", color: "#d97706", badge_class: "bg-amber-500/15 text-amber-600 dark:text-amber-400 border-amber-500/30" }
      elsif s >= 25.0
        { level: "ELEVATED", color: "#2563eb", badge_class: "bg-blue-500/15 text-blue-600 dark:text-blue-400 border-blue-500/30" }
      else
        { level: "LIMITED", color: "#10b981", badge_class: "bg-emerald-500/15 text-emerald-600 dark:text-emerald-400 border-emerald-500/30" }
      end
    end

    def calculate_overall_cascade_risk(threatened_roads, scenarios)
      return 0.0 if threatened_roads.empty? && scenarios.empty?

      max_scen = scenarios.map { |s| s[:cascade_score].to_f }.max || 0.0
      avg_threat = threatened_roads.sum { |r| r[:expected_operational_threat].to_f } / [threatened_roads.size, 1].max.to_f

      ((max_scen * 0.6) + (avg_threat * 0.4)).clamp(0.0, 100.0)
    end

    def compile_consolidated_recommendations(scenarios, top_candidates, trend)
      recs = []
      scenarios.first(3).each do |scen|
        recs.concat(Array(scen[:recommendations]))
      end
      if recs.empty? && top_candidates.any?
        cand = top_candidates.first
        recs << {
          action: "Monitor #{cand[:road_number]} with regular telemetry polling.",
          why: "Baseline threat score #{cand[:expected_operational_threat]} with #{cand[:prediction_confidence]}% confidence.",
          when: "Immediate",
          where: cand[:road_name],
          priority: cand[:expected_operational_threat] >= 50.0 ? "HIGH" : "MEDIUM",
          owner_type: "OPERATIONS_HQ",
          timeframe: "< 12h",
          title: "Active Monitoring",
          counterfactual_simulation: "Continuous monitoring prevents unobserved disruptions.",
          simulated_risk_reduction_pct: 15.0
        }
      end
      recs.uniq { |r| r[:action] }.first(5)
    end

    def compile_overall_explanations(threatened_roads, scenarios, trend, overall_risk)
      exps = []
      if scenarios.any?
        top_s = scenarios.first
        exps << "Top cascading threat is '#{top_s[:name]}' with a cascade score of #{top_s[:cascade_score]}/100."
        exps << top_s[:consequence_summary] if top_s[:consequence_summary].present?
      end
      if trend[:signals]&.any?
        exps << "Key trend signals: #{trend[:signals].join(', ')}."
      end
      if exps.empty?
        exps << "Transportation network operating normally with stable connectivity."
      end
      exps
    end

    def compile_overall_warnings(threatened_roads, trend)
      warns = []
      low_conf = threatened_roads.select { |r| r[:prediction_confidence] < 55.0 }
      if low_conf.any?
        warns << "#{low_conf.size} corridors have low data confidence (< 55%); UAV or field officer verification advised."
      end
      if trend[:direction] == "ESCALATING"
        warns << "Cascading failure trend is ESCALATING over the forecast horizon."
      end
      warns
    end

    def compile_projected_impact_summary(scenarios, base_network_analysis)
      isolated_settlements = scenarios.flat_map { |s| s[:isolated_settlements] || [] }.uniq { |st| st[:id] }
      isolated_warehouses = scenarios.flat_map { |s| s[:isolated_warehouses] || [] }.uniq { |w| w[:id] }
      total_pop = isolated_settlements.sum { |s| s[:population].to_i }
      total_settlements = @locations.count { |l| l.location_type != "Warehouse" }
      total_wh = @warehouses.size

      baseline_health = base_network_analysis[:network_health_score].to_f
      forecast_health = if scenarios.any?
                          min_health = scenarios.map { |s| s.dig(:projected_impact, :network_health_after).to_f }.reject(&:zero?).min
                          min_health || (baseline_health * 0.85).round(1)
                        else
                          baseline_health
                        end

      {
        settlements_at_risk: isolated_settlements.size,
        total_settlements: total_settlements,
        isolated_settlements_count: base_network_analysis[:isolated_settlements_count].to_i,
        population_at_risk: total_pop,
        warehouses_at_risk: isolated_warehouses.size,
        total_warehouses: total_wh,
        network_health_forecast: forecast_health.round(1)
      }
    end

    def build_contributing_signals_list(road_risk, ml_prob, incident_signal, weather_escalation, criticality_score)
      signals = []
      signals << "Elevated baseline road risk (#{road_risk.round(1)}/100)" if road_risk >= 50.0
      signals << "High ML disruption probability (#{ml_prob.round(1)}%)" if ml_prob >= 50.0
      signals << "Corroborated incident report (#{incident_signal.round(1)}%)" if incident_signal >= 40.0
      signals << "Severe weather conditions (#{weather_escalation.round(1)}%)" if weather_escalation >= 50.0
      signals << "High topological criticality (#{criticality_score.round(1)}/100)" if criticality_score >= 50.0
      signals << "Nominal operating conditions" if signals.empty?
      signals
    end

    def build_road_explanations(road, failure_prob, road_risk, ml_prob, incident_info, weather_info, criticality_score, pred_conf)
      reasons = []
      reasons << "#{road.road_number} has an estimated failure probability of #{failure_prob}%."
      if incident_info[:primary_incident]
        reasons << "Active #{incident_info[:primary_incident].incident_type} reported with confidence #{incident_info[:confidence_signal]}%."
      end
      if weather_info[:data_available] && weather_info[:weather_signal] >= 50.0
        reasons << "Weather escalation factor is high (#{weather_info[:weather_signal]}/100)."
      end
      reasons << "Infrastructure criticality is #{criticality_score.round(1)}/100 with prediction confidence at #{pred_conf}%."
      reasons
    end

    def build_road_warnings(road, failure_prob, weather_info, incident_info, pred_conf)
      warnings = []
      if pred_conf < 55.0 || incident_info[:confidence_signal].to_f < 55.0
        warnings << "LOW data confidence (#{pred_conf}%) on #{road.road_number}; recommend ground recon."
      end
      warnings << "Missing real-time weather telemetry for #{road.road_number}." unless weather_info[:data_available]
      warnings << "Critical failure imminent for #{road.road_number} (Probability #{failure_prob}%)." if failure_prob >= 75.0
      warnings
    end

    # =========================================================================
    # HELPERS: SIGNALS, EXTRACTORS & CORRELATIONS
    # =========================================================================
    private

    def extract_road_risk(road)
      db_score = road.risk_score.presence&.to_f
      if db_score && db_score > 0.0
        return db_score
      end

      if defined?(ResQWay::RoadRiskIntelligenceService)
        begin
          dynamic = ResQWay::RoadRiskIntelligenceService.new(road).calculate[:risk_score].to_f
          dynamic.positive? ? dynamic : 25.0
        rescue StandardError
          25.0
        end
      else
        25.0
      end
    end

    def extract_ml_probability(road, fallback: 25.0)
      raw = road.try(:ml_disruption_probability)
      fallback_val = road.risk_score.presence&.to_f || fallback
      normalize_ml_probability(raw, fallback: fallback_val)
    end

    def normalize_ml_probability(val, fallback: 25.0)
      return fallback.to_f.clamp(0.0, 100.0) if val.nil?

      v = val.to_f
      if v <= 1.0 && v > 0.0
        (v * 100.0).clamp(0.0, 100.0)
      else
        v.clamp(0.0, 100.0)
      end
    end

    def extract_incident_signals(road)
      return { incident_signal: 0.0, confidence_signal: 70.0, primary_incident: nil } unless defined?(Incident)

      # Bounded spatial search for active incidents in proximity to road
      lat = road.latitude&.to_f
      lon = road.longitude&.to_f

      scope = Incident.where(status: %w[reported verified])
                      .where("reported_at >= ?", 72.hours.ago)

      if lat && lon
        scope = scope.where(latitude: (lat - 0.35)..(lat + 0.35), longitude: (lon - 0.35)..(lon + 0.35))
      elsif road.state.present?
        scope = scope.where(state: road.state)
      end

      nearby = scope.limit(20).to_a
      return { incident_signal: 0.0, confidence_signal: 70.0, primary_incident: nil } if nearby.empty?

      # Find strongest correlated incident signal
      best_signal = 0.0
      best_incident = nil

      nearby.each do |inc|
        base_severity = case inc.severity.to_s.downcase
                        when "critical" then 95.0
                        when "high"     then 75.0
                        when "medium"   then 45.0
                        when "low"      then 20.0
                        else 30.0
                        end

        conf_score = inc.try(:ai_confidence_score) || inc.try(:confidence_score) || 70.0
        multiplier = confidence_multiplier(conf_score)
        scaled = base_severity * multiplier

        if scaled > best_signal
          best_signal = scaled
          best_incident = inc
        end
      end

      conf_signal = best_incident&.try(:ai_confidence_score) || best_incident&.try(:confidence_score) || 70.0

      {
        incident_signal: best_signal.clamp(0.0, 100.0),
        confidence_signal: conf_signal.to_f.clamp(0.0, 100.0),
        primary_incident: best_incident
      }
    end

    def confidence_multiplier(score)
      case score.to_f
      when 90.0..100.0 then 1.0
      when 75.0...90.0 then 0.9
      when 55.0...75.0 then 0.7
      else 0.5
      end
    end

    def extract_weather_escalation(road)
      lat = road.latitude&.to_f
      lon = road.longitude&.to_f

      unless lat && lon && defined?(WeatherService)
        return { weather_signal: 25.0, data_available: false, weather_data: nil }
      end

      weather = begin
        WeatherService.fetch(lat, lon)
      rescue StandardError => e
        Rails.logger.warn("[PredictiveCascadingImpactService] Weather fetch failed: #{e.message}")
        nil
      end

      return { weather_signal: 25.0, data_available: false, weather_data: nil } if weather.nil?

      precip = (weather[:precipitation] || weather[:precipitation_mm]).to_f
      rain_level = (weather[:rainfall] || weather[:rainfall_level]).to_s.downcase
      condition = (weather[:condition] || weather[:condition_text]).to_s.downcase
      alerts = Array(weather[:alerts])

      score = 20.0
      if %w[extreme torrential].include?(rain_level) || precip >= 50.0 || alerts.any?
        score = 90.0
      elsif rain_level == "heavy" || precip >= 25.0
        score = 75.0
      elsif rain_level == "moderate" || precip >= 10.0
        score = 50.0
      elsif rain_level == "light" || precip >= 2.0
        score = 30.0
      elsif condition.include?("clear") || condition.include?("sunny") || rain_level == "none"
        score = 10.0
      end

      # High-altitude terrain vulnerability escalation
      if %w[Sikkim Arunachal\ Pradesh].include?(road.state) && score >= 50.0
        score = [score + 10.0, 100.0].min
      end

      {
        weather_signal: score.clamp(0.0, 100.0),
        data_available: true,
        weather_data: weather
      }
    end

    def calculate_prediction_confidence(weather_info, ml_prob, primary_incident, road)
      score = 0.0

      # Factor 1: Weather availability (+25)
      score += weather_info[:data_available] ? 25.0 : 10.0

      # Factor 2: ML disruption probability (+25)
      score += road.try(:ml_disruption_probability).present? ? 25.0 : 12.0

      # Factor 3: Incident evidence confidence (+30)
      if primary_incident.present?
        inc_conf = primary_incident.try(:ai_confidence_score) || primary_incident.try(:confidence_score) || 70.0
        score += (inc_conf.to_f * 0.30)
      else
        score += 20.0 # Neutral baseline if no incidents
      end

      # Factor 4: Coordinate and topology integrity (+20)
      score += (road.latitude.present? && road.longitude.present?) ? 20.0 : 5.0

      score.clamp(10.0, 100.0).round(1)
    end

    def classify_prediction_confidence_level(conf_score)
      if conf_score >= 80.0
        "HIGH"
      elsif conf_score >= 55.0
        "MODERATE"
      else
        "LOW"
      end
    end

    def build_critical_roads_map(base_network_analysis)
      map = {}
      critical_roads = base_network_analysis[:critical_roads] || []
      critical_roads.each do |cr|
        rid = cr[:road_id] || cr[:id]
        map[rid] = cr[:criticality_score].to_f if rid
      end
      map
    end

    def roads_correlated?(road1, road2)
      return false if road1.id == road2.id

      # 1. Topological: Share an endpoint node
      if roads_share_endpoint?(road1, road2)
        return true
      end

      # 2. Geographic: Midpoint distance <= 50km and same state
      if road1.state.present? && road1.state == road2.state
        dist = road_midpoint_distance(road1, road2)
        return true if dist && dist <= 50.0
      end

      false
    end

    def roads_adjacent?(road1, road2)
      return false if road1.nil? || road2.nil? || road1.id == road2.id
      roads_share_endpoint?(road1, road2)
    end

    def roads_share_endpoint?(r1, r2)
      o1, d1 = r1.try(:origin_location_id), r1.try(:destination_location_id)
      o2, d2 = r2.try(:origin_location_id), r2.try(:destination_location_id)

      if o1 && d1 && o2 && d2
        return true if o1 == o2 || o1 == d2 || d1 == o2 || d1 == d2
      end

      # Fallback to proximity of geometry endpoints
      coords1 = r1.coordinates || []
      coords2 = r2.coordinates || []
      if coords1.size >= 2 && coords2.size >= 2
        pts1 = [coords1.first, coords1.last]
        pts2 = [coords2.first, coords2.last]
        pts1.each do |p1|
          pts2.each do |p2|
            return true if haversine_distance(p1[0], p1[1], p2[0], p2[1]) <= 15.0
          end
        end
      end

      false
    end

    def road_midpoint_distance(r1, r2)
      lat1, lon1 = road_midpoint(r1)
      lat2, lon2 = road_midpoint(r2)
      return nil if lat1.nil? || lat2.nil?

      haversine_distance(lat1, lon1, lat2, lon2)
    end

    def road_midpoint(road)
      coords = road.coordinates || []
      if coords.size >= 2
        mid = coords[coords.size / 2]
        [mid[0].to_f, mid[1].to_f]
      elsif road.latitude.present? && road.longitude.present?
        [road.latitude.to_f, road.longitude.to_f]
      else
        [nil, nil]
      end
    end

    def haversine_distance(lat1, lon1, lat2, lon2)
      return 9999.0 if lat1.nil? || lon1.nil? || lat2.nil? || lon2.nil?

      dlat = (lat2 - lat1) * Math::PI / 180.0
      dlon = (lon2 - lon1) * Math::PI / 180.0

      a = (Math.sin(dlat / 2.0)**2) +
          (Math.cos(lat1 * Math::PI / 180.0) * Math.cos(lat2 * Math::PI / 180.0) * (Math.sin(dlon / 2.0)**2))
      c = 2.0 * Math.atan2(Math.sqrt(a), Math.sqrt(1.0 - a))
      (EARTH_RADIUS_KM * c).round(2)
    end

    def classify_matrix_action(failure_prob, cascade_score)
      fp = failure_prob.to_f
      cs = cascade_score.to_f
      if fp >= 50.0 && cs >= 60.0
        "PREEMPTIVE_REROUTE_AND_STAGING"
      elsif fp >= 50.0
        "ACTIVE_MONITORING_AND_TACTICAL_HOLD"
      elsif cs >= 60.0
        "CONTINGENCY_STAGING_WATCHLIST"
      else
        "ROUTINE_MONITORING"
      end
    end

    def empty_analysis_result(forecast_hours, start_clock = nil)
      elapsed_ms = if start_clock
                     ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_clock) * 1000.0).round(1)
                   else
                     1.0
                   end

      {
        status: "complete",
        generated_at: Time.current,
        forecast_horizon: forecast_hours,
        overall_cascade_risk: 0.0,
        risk_level: "LIMITED",
        risk_color: "#10b981",
        risk_badge_class: "bg-emerald-100 dark:bg-emerald-950 text-emerald-800 dark:text-emerald-300 border-emerald-300 dark:border-emerald-800 font-medium",
        trend: { score: 0.0, direction: "STABLE", signals: ["Empty network topology."] },
        summary: {
          overall_cascade_risk: 0.0,
          risk_level: "LIMITED",
          prediction_confidence: 100.0,
          threatened_population: 0,
          actionable_scenarios_count: 0,
          verification_watchlist_count: 0
        },
        instrumentation: {
          candidates_evaluated: 0,
          simulations_performed: 0,
          execution_time_ms: elapsed_ms,
          cache_hits: 0
        },
        threatened_roads: [],
        top_candidates: [],
        scenarios: [],
        top_scenario: nil,
        watchlist: [],
        cascade_stages: [],
        failure_dependency_graph: {},
        projected_impact: {
          settlements_at_risk: 0,
          total_settlements: 0,
          isolated_settlements_count: 0,
          population_at_risk: 0,
          warehouses_at_risk: 0,
          total_warehouses: 0,
          network_health_forecast: 100.0
        },
        recommendations: [],
        alerts_generated_count: 0,
        explanation: ["No road corridors or settlement nodes registered in transportation graph."],
        warnings: ["Empty transport network topology. Add locations and roads to evaluate predictive cascading impacts."],
        ranking_explanation: { ranking_method: "EOT = (P * I * C) / 10000", narrative: "No active roads" },
        metadata: {
          roads_analyzed: 0,
          scenarios_generated: 0,
          simulation_calls: 0,
          simulation_budget: {
            allowed: MAX_SIMULATION_BUDGET,
            used: 0
          },
          bounded: true
        }
      }
    end
  end
end
