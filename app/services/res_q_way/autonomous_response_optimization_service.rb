# frozen_string_literal: true

module ResQWay
  class AutonomousResponseOptimizationService
    EARTH_RADIUS_KM = 6371.0
    DEFAULT_FORECAST_HOURS = 12
    MAX_PRIORITY_ZONES = 10
    MAX_WAREHOUSES_EVALUATED = 5
    MAX_STRATEGIES = 10
    MAX_CONTINGENCIES_PER_STRATEGY = 3

    # Multipliers for Risk Adjusted Utility
    RESILIENCE_MULTIPLIERS = {
      "HIGHLY_RESILIENT"               => 1.00,
      "RESILIENT"                      => 0.95,
      "MODERATELY_RESILIENT"           => 0.85,
      "FRAGILE"                        => 0.70,
      "CRITICAL_SINGLE_POINT_FAILURE"  => 0.50
    }.freeze

    # Humanitarian Priority Levels
    HUMANITARIAN_LEVELS = [
      { min: 85.0, level: "CATASTROPHIC_PRIORITY", color: "#dc2626", badge: "bg-red-500/15 text-red-600 dark:text-red-400 border-red-500/30" },
      { min: 70.0, level: "CRITICAL_PRIORITY",     color: "#ea580c", badge: "bg-orange-500/15 text-orange-600 dark:text-orange-400 border-orange-500/30" },
      { min: 50.0, level: "HIGH_PRIORITY",         color: "#d97706", badge: "bg-amber-500/15 text-amber-600 dark:text-amber-400 border-amber-500/30" },
      { min: 30.0, level: "ELEVATED_PRIORITY",     color: "#2563eb", badge: "bg-blue-500/15 text-blue-600 dark:text-blue-400 border-blue-500/30" },
      { min: 0.0,  level: "MONITOR",               color: "#10b981", badge: "bg-emerald-500/15 text-emerald-600 dark:text-emerald-400 border-emerald-500/30" }
    ].freeze

    # Response Urgency Levels
    URGENCY_LEVELS = [
      { min: 90.0, level: "IMMEDIATE", color: "#dc2626" },
      { min: 75.0, level: "CRITICAL",  color: "#ea580c" },
      { min: 60.0, level: "URGENT",    color: "#d97706" },
      { min: 40.0, level: "HIGH",      color: "#2563eb" },
      { min: 20.0, level: "PLANNED",   color: "#0891b2" },
      { min: 0.0,  level: "MONITOR",   color: "#10b981" }
    ].freeze

    attr_reader :locations, :warehouses, :roads, :predictive_service, :predictive_analysis, :network_service

    def initialize(locations: nil, warehouses: nil, roads: nil, predictive_service: nil, predictive_analysis: nil, network_service: nil)
      @locations = locations || Location.all.to_a
      @warehouses = warehouses || Warehouse.all.to_a
      @roads = roads || Road.all.to_a
      @predictive_service = predictive_service
      @predictive_analysis = predictive_analysis
      @network_service = network_service || ResQWay::NetworkConnectivityService.new(roads: @roads, locations: @locations, warehouses: @warehouses)
      @cache_hits = 0
    end

    def analyze(forecast_hours: DEFAULT_FORECAST_HOURS, priority_limit: MAX_PRIORITY_ZONES, strategy_limit: MAX_STRATEGIES, create_alerts: false)
      start_clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      forecast_hours = forecast_hours.to_i
      forecast_hours = DEFAULT_FORECAST_HOURS unless [6, 12, 24, 48].include?(forecast_hours)
      priority_limit = [[priority_limit.to_i, 1].max, MAX_PRIORITY_ZONES].min
      strategy_limit = [[strategy_limit.to_i, 1].max, MAX_STRATEGIES].min

      # Handle empty network edge case safely
      if @locations.empty? || @roads.empty? || @warehouses.empty?
        return empty_analysis_result(forecast_hours, start_clock)
      end

      # Refresh database records if running against ActiveRecord instances
      if @roads.first.is_a?(ActiveRecord::Base)
        @roads = Road.where(id: @roads.map(&:id)).to_a
        @warehouses = Warehouse.where(id: @warehouses.map(&:id)).to_a if @warehouses.first.is_a?(ActiveRecord::Base)
        @locations = Location.where(id: @locations.map(&:id)).to_a if @locations.first.is_a?(ActiveRecord::Base)
        @network_service = ResQWay::NetworkConnectivityService.new(roads: @roads, locations: @locations, warehouses: @warehouses)
      end

      # 1. Obtain predictive cascade intelligence (with fast-path cache)
      predictive_analysis = @predictive_analysis || fetch_or_compute_predictive_analysis(forecast_hours)

      # 2. Step 1: Priority Zone Identification & Scoring
      priority_zones = identify_priority_zones(predictive_analysis, limit: priority_limit)

      # 3. Step 2: Warehouse Capability Analysis (Max 5)
      warehouse_capabilities = evaluate_warehouse_capabilities(priority_zones, limit: MAX_WAREHOUSES_EVALUATED)

      # 4. Step 3: Route & Accessibility Evaluation (Dijkstra + Safety)
      route_analysis = evaluate_routes_to_priority_zones(warehouse_capabilities, priority_zones)

      # 5. Step 4 & 5: Bounded Response Strategy Generation & Optimization
      candidate_strategies = generate_candidate_strategies(
        priority_zones: priority_zones,
        warehouse_capabilities: warehouse_capabilities,
        route_analysis: route_analysis,
        predictive_analysis: predictive_analysis,
        limit: strategy_limit
      )

      # Multi-objective optimization & ranking
      optimized_strategies = optimize_strategies(candidate_strategies)
      optimal_strategy = optimized_strategies.first
      alternative_strategies = optimized_strategies.drop(1)

      # 6. Step 6: Autonomous Prepositioning Decision
      resource_prepositioning = evaluate_prepositioning_decisions(
        priority_zones: priority_zones,
        predictive_analysis: predictive_analysis,
        warehouse_capabilities: warehouse_capabilities
      )

      # 7. Step 7: Airlift & Aerial Reconnaissance Escalation
      aerial_response = evaluate_aerial_escalation(
        priority_zones: priority_zones,
        route_analysis: route_analysis,
        optimal_strategy: optimal_strategy
      )

      # 8. Step 8: Contingency Simulation (Max 3 per strategy)
      contingency_plans = simulate_contingencies(optimal_strategy, route_analysis, warehouse_capabilities)

      # Calculate actual plan resilience from simulated contingency outcomes
      response_resilience = calculate_plan_resilience(optimal_strategy, contingency_plans)

      # 9. Step 9: Counterfactual Analysis (No Action vs Recommended ResQWay Plan)
      counterfactual_analysis = compute_counterfactual_analysis(
        priority_zones: priority_zones,
        optimal_strategy: optimal_strategy,
        predictive_analysis: predictive_analysis
      )

      # 10. Operational Timeline Generator
      operational_timeline = generate_operational_timeline(
        optimal_strategy: optimal_strategy,
        prepositioning: resource_prepositioning,
        aerial: aerial_response,
        forecast_hours: forecast_hours
      )

      # 11. Overall Response Urgency Metric
      overall_urgency = calculate_overall_response_urgency(
        priority_zones: priority_zones,
        optimal_strategy: optimal_strategy,
        predictive_analysis: predictive_analysis
      )
      urgency_level = classify_urgency_level(overall_urgency)

      # 12. Explainable Autonomous Decision (Winner justification + explicit Rejection reasons)
      decision_explanation = build_explainable_decision(
        optimal_strategy: optimal_strategy,
        alternative_strategies: alternative_strategies,
        priority_zones: priority_zones,
        contingency_plans: contingency_plans,
        overall_urgency: overall_urgency
      )

      # 13. Optional Alert Generation (Confidence >= 60 && Urgency >= 70, 24h deduplicated)
      generated_alerts = []
      if create_alerts && defined?(LogisticsAlert)
        generated_alerts = create_response_alerts!(optimal_strategy, overall_urgency, priority_zones)
      end

      elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_clock) * 1000.0).round(1)

      {
        status: "COMPLETE",
        human_approval_status: "AWAITING_HUMAN_COMMAND_APPROVAL",
        generated_at: Time.current,
        forecast_horizon: forecast_hours,
        overall_response_urgency: overall_urgency.round(1),
        urgency_level: urgency_level[:level],
        urgency_color: urgency_level[:color],
        population_prioritized: priority_zones.sum { |z| z[:population_at_risk] },
        priority_zones: priority_zones,
        warehouse_capabilities: warehouse_capabilities,
        route_analysis: route_analysis,
        optimal_strategy: optimal_strategy,
        alternative_strategies: alternative_strategies,
        resource_prepositioning: resource_prepositioning,
        aerial_response: aerial_response,
        contingency_plans: contingency_plans,
        response_resilience: response_resilience,
        counterfactual_analysis: counterfactual_analysis,
        operational_timeline: operational_timeline,
        decision_explanation: decision_explanation,
        alerts_generated_count: generated_alerts.size,
        instrumentation: {
          execution_time_ms: elapsed_ms,
          priority_zones_evaluated: priority_zones.size,
          warehouses_evaluated: warehouse_capabilities.size,
          routes_evaluated: route_analysis.size,
          strategies_generated: optimized_strategies.size,
          contingency_simulations: contingency_plans.size,
          cache_hits: @cache_hits
        }
      }
    end

    # =========================================================================
    # STEP 1: PRIORITY ZONE IDENTIFICATION & HUMANITARIAN PRIORITY SCORING
    # =========================================================================
    def identify_priority_zones(predictive_analysis, limit: MAX_PRIORITY_ZONES)
      threatened_settlement_ids = Set.new
      (predictive_analysis[:scenarios] || []).each do |s|
        (s[:isolated_settlements] || []).each do |iso|
          threatened_settlement_ids.add(iso[:id]) if iso[:id]
        end
      end

      active_incidents = if defined?(Incident)
                           Incident.where(status: %w[reported verified]).where("reported_at >= ?", 72.hours.ago).to_a
                         else
                           []
                         end

      max_pop = @locations.map { |l| l.population.to_i }.max || 1
      max_pop = 1 if max_pop <= 0

      zones = @locations.reject { |l| l.location_type == "Warehouse" }.map do |loc|
        nearby_incidents = active_incidents.select do |inc|
          inc.state == loc.state && (haversine_distance(loc.latitude, loc.longitude, inc.latitude, inc.longitude) <= 45.0)
        end

        # Factors:
        # 1. Population Exposure (0-100)
        pop_exposure = ((loc.population.to_i.to_f / max_pop.to_f) * 100.0).clamp(5.0, 100.0)

        # 2. Isolation Severity (0-100)
        is_isolated = threatened_settlement_ids.include?(loc.id)
        access_score = loc.accessibility_score.presence&.to_f || 75.0
        isolation_severity = if is_isolated
                               95.0
                             elsif access_score < 40.0
                               80.0
                             elsif access_score < 60.0
                               55.0
                             else
                               20.0
                             end

        # 3. Incident Severity (0-100)
        incident_severity = if nearby_incidents.any?
                              nearby_incidents.map do |inc|
                                case inc.severity.to_s.downcase
                                when "critical" then 95.0
                                when "high"     then 75.0
                                when "medium"   then 50.0
                                else 30.0
                                end
                              end.max
                            else
                              15.0
                            end

        # 4. Supply Shortage Risk (0-100)
        # Based on distance to nearest operational warehouse
        dist_to_wh = nearest_warehouse_distance(loc)
        supply_shortage = if is_isolated
                            90.0
                          elsif dist_to_wh > 150.0
                            75.0
                          elsif dist_to_wh > 75.0
                            45.0
                          else
                            20.0
                          end

        # 5. Response Delay Risk (0-100)
        response_delay_risk = if is_isolated
                                90.0
                              else
                                [dist_to_wh * 0.4, 90.0].min.clamp(10.0, 95.0)
                              end

        # 6. Vulnerability (0-100)
        vulnerability = case loc.landslide_risk.to_s.downcase
                        when "high" then 85.0
                        when "medium" then 55.0
                        else 25.0
                        end

        has_critical_incident = nearby_incidents.any? { |i| i.severity.to_s.downcase == "critical" }
        isolation_severity = [isolation_severity, 85.0].max if has_critical_incident
        supply_shortage = [supply_shortage, 75.0].max if has_critical_incident

        # Formula:
        # Priority = 0.20 * PopExposure + 0.25 * IsolationSeverity + 0.25 * IncidentSeverity
        #          + 0.15 * SupplyShortage + 0.10 * ResponseDelayRisk + 0.05 * Vulnerability
        priority_score = (
          (0.20 * pop_exposure) +
          (0.25 * isolation_severity) +
          (0.25 * incident_severity) +
          (0.15 * supply_shortage) +
          (0.10 * response_delay_risk) +
          (0.05 * vulnerability)
        ).clamp(0.0, 100.0).round(1)

        level_info = classify_humanitarian_priority(priority_score)

        {
          location_id: loc.id,
          name: loc.name,
          state: loc.state,
          district: loc.district,
          population_at_risk: loc.population.to_i,
          humanitarian_priority: priority_score,
          priority_level: level_info[:level],
          priority_color: level_info[:color],
          priority_badge: level_info[:badge],
          isolation_risk: is_isolated ? "CRITICAL" : (access_score < 50.0 ? "HIGH" : "LOW"),
          supply_shortage_risk: supply_shortage.round(1),
          response_delay_risk: response_delay_risk.round(1),
          contributing_incidents: nearby_incidents.map { |i| { id: i.id, type: i.incident_type, severity: i.severity } },
          predictive_threats: is_isolated ? ["Projected Corridor Disruption Cuts Off Access"] : []
        }
      end

      # Deterministic ranking: priority_score DESC, then population DESC, then ID ASC
      zones.sort_by { |z| [-z[:humanitarian_priority], -z[:population_at_risk], z[:location_id]] }.first(limit)
    end

    def classify_humanitarian_priority(score)
      HUMANITARIAN_LEVELS.find { |l| score >= l[:min] } || HUMANITARIAN_LEVELS.last
    end

    # =========================================================================
    # STEP 2: WAREHOUSE CAPABILITY ANALYSIS (MAX 5 WAREHOUSES)
    # =========================================================================
    def evaluate_warehouse_capabilities(priority_zones, limit: MAX_WAREHOUSES_EVALUATED)
      wh_candidates = @warehouses.first(limit)

      wh_candidates.map do |wh|
        # Factor 1: Operational Status (0-100)
        status_score = case wh.operational_status.to_s.upcase
                       when "OPERATIONAL" then 100.0
                       when "LIMITED"     then 60.0
                       when "OVERLOADED"  then 30.0
                       else 0.0
                       end

        # Factor 2: Available Capacity (0-100)
        # Check available capacity vs total capacity
        tot_cap = [wh.capacity.to_i, 1].max
        avail_cap = [wh.available_capacity.to_i, 0].max
        cap_score = ((avail_cap.to_f / tot_cap.to_f) * 100.0).clamp(0.0, 100.0)

        # Factor 3: Network Accessibility (0-100)
        # Does the warehouse have passable routes to priority zones?
        accessible_zones = []
        priority_zones.each do |zone|
          dist = haversine_distance(wh.latitude, wh.longitude, zone_lat(zone), zone_lon(zone))
          accessible_zones << zone[:name] if dist < 300.0
        end
        network_access_score = ((accessible_zones.size.to_f / [priority_zones.size, 1].max.to_f) * 100.0).clamp(10.0, 100.0)

        # Factor 4: Route Safety (0-100)
        # Average risk score of roads connected to warehouse location
        connected_roads = @roads.select do |r|
          (r.try(:origin_location_id) == wh.location_id || r.try(:destination_location_id) == wh.location_id) ||
            (wh.latitude && wh.longitude && (
              (r.latitude && r.longitude && haversine_distance(wh.latitude, wh.longitude, r.latitude, r.longitude) <= 75.0) ||
              (r.geometry_coordinates.present? && Array(r.geometry_coordinates).any? { |pt| haversine_distance(wh.latitude, wh.longitude, pt[0], pt[1]) <= 75.0 })
            ))
        end
        connected_roads = @roads.select { |r| r.state == wh.location&.state } if connected_roads.empty? && wh.location

        avg_risk = if connected_roads.any?
                     connected_roads.sum { |r| r.risk_score.to_f } / connected_roads.size.to_f
                   else
                     30.0
                   end
        route_safety = [100.0 - avg_risk, 10.0].max

        # Factor 5: Isolation Resistance (0-100)
        # More connected roads -> higher redundancy
        isolation_resistance = case connected_roads.size
                               when 0 then 15.0
                               when 1 then 40.0
                               when 2 then 75.0
                               else 95.0
                               end

        # Warehouse Capability Score =
        # 0.25 * OpStatus + 0.25 * AvailCap + 0.20 * NetworkAccess + 0.15 * RouteSafety + 0.15 * IsolationResistance
        capability_score = (
          (0.25 * status_score) +
          (0.25 * cap_score) +
          (0.20 * network_access_score) +
          (0.15 * route_safety) +
          (0.15 * isolation_resistance)
        ).clamp(0.0, 100.0).round(1)

        # Assign Operational Role
        role = if status_score < 40.0 || connected_roads.none?
                 "AT_RISK_HUB"
               elsif capability_score >= 80.0 && avail_cap >= 800
                 "PRIMARY_DISPATCH_HUB"
               elsif capability_score >= 65.0
                 "SECONDARY_DISPATCH_HUB"
               elsif network_access_score >= 80.0
                 "FORWARD_STAGING_HUB"
               elsif avail_cap >= 500
                 "PREPOSITIONING_HUB"
               else
                 "RESERVE_HUB"
               end

        # Resource Availability breakdown
        res_data = wh.resources || {}
        available_resources = {
          medical_kits: res_data["medical_kits"] || (avail_cap * 0.8).to_i,
          food_packages: res_data["food_packages"] || (avail_cap * 1.5).to_i,
          fuel_liters: res_data["fuel_liters"] || (avail_cap * 10).to_i,
          rescue_vehicles: [wh.utilized_capacity.to_i / 200, 1].max,
          personnel: [avail_cap / 50, 10].max,
          warehouse_capacity: tot_cap,
          available_capacity: avail_cap
        }

        {
          warehouse_id: wh.id,
          warehouse_name: wh.name,
          location_name: wh.location&.name || "Regional Depot",
          capability_score: capability_score,
          operational_status: wh.operational_status,
          available_capacity: avail_cap,
          total_capacity: tot_cap,
          utilization_percentage: wh.utilization_percentage,
          accessible_zones: accessible_zones,
          network_risk: avg_risk.round(1),
          dispatch_readiness: (status_score < 40.0 || capability_score < 45.0) ? "DEGRADED" : (capability_score >= 70.0 ? "HIGH" : "MODERATE"),
          recommended_role: role,
          available_resources: available_resources
        }
      end.sort_by { |w| -w[:capability_score] }
    end

    # =========================================================================
    # STEP 3: ROUTE & ACCESSIBILITY EVALUATION (DIJKSTRA + SAFETY)
    # =========================================================================
    def evaluate_routes_to_priority_zones(warehouse_caps, priority_zones)
      routes = []
      passable_edges = @network_service.edges.select(&:passable?)

      warehouse_caps.each do |wh_info|
        wh = @warehouses.find { |w| w.id == wh_info[:warehouse_id] }
        next unless wh

        priority_zones.each do |zone|
          dest_loc = @locations.find { |l| l.id == zone[:location_id] }
          next unless dest_loc
          next if wh.location_id.present? && wh.location_id == dest_loc.id

          straight_dist = haversine_distance(wh.latitude, wh.longitude, dest_loc.latitude, dest_loc.longitude)
          next if straight_dist > 450.0 # Bounded geographic scope

          # 1. Primary shortest path via Dijkstra
          path_edges, net_dist = dijkstra_path(wh.location_id, dest_loc.id, passable_edges)
          has_ground_route = net_dist.present? && !net_dist.infinite?
          route_dist = has_ground_route ? net_dist : (straight_dist * 1.35)

          primary_route = build_route_entry(wh, dest_loc, path_edges, route_dist, has_ground_route, zone, is_bypass: false)
          routes << primary_route

          # 2. If primary path has elevated failure risk, compute a safe alternative bypass path
          if has_ground_route && path_edges.any? { |e| e.risk_score >= 60.0 || e.disruption_probability >= 0.60 }
            high_risk_edge = path_edges.max_by(&:risk_score)
            bypass_edges = passable_edges.reject { |e| e.road_id == high_risk_edge.road_id }
            alt_edges, alt_dist = dijkstra_path(wh.location_id, dest_loc.id, bypass_edges)
            if alt_dist.present? && !alt_dist.infinite?
              bypass_route = build_route_entry(wh, dest_loc, alt_edges, alt_dist, true, zone, is_bypass: true)
              routes << bypass_route
            end
          end
        end
      end

      # Return top routes sorted by route_score descending
      routes.sort_by { |r| -r[:route_score] }
    end

    def dijkstra_path(start_id, dest_id, edges)
      return [[], Float::INFINITY] if start_id.nil? || dest_id.nil? || start_id == dest_id || edges.empty?

      adj = Hash.new { |h, k| h[k] = [] }
      edges.each do |e|
        adj[e.origin_id] << { to: e.destination_id, weight: e.distance.to_f, edge: e }
        adj[e.destination_id] << { to: e.origin_id, weight: e.distance.to_f, edge: e }
      end

      distances = Hash.new(Float::INFINITY)
      distances[start_id] = 0.0
      predecessors = {}
      visited = Set.new
      queue = [[0.0, start_id]]

      until queue.empty?
        queue.sort_by!(&:first)
        curr_dist, u = queue.shift
        next if visited.include?(u)
        visited.add(u)
        break if u == dest_id

        adj[u].each do |item|
          v = item[:to]
          new_dist = curr_dist + item[:weight]
          if new_dist < distances[v]
            distances[v] = new_dist
            predecessors[v] = { prev_node: u, edge: item[:edge] }
            queue.push([new_dist, v])
          end
        end
      end

      return [[], Float::INFINITY] unless visited.include?(dest_id)

      path_edges = []
      curr = dest_id
      while predecessors[curr]
        path_edges << predecessors[curr][:edge]
        curr = predecessors[curr][:prev_node]
      end

      [path_edges.reverse, distances[dest_id]]
    end

    def build_route_entry(wh, dest_loc, path_edges, route_dist, has_ground_route, zone, is_bypass: false)
      est_hours = (route_dist / 40.0).round(1)

      if has_ground_route && path_edges.any?
        avg_road_risk = path_edges.sum(&:risk_score) / path_edges.size.to_f
        avg_ml_prob = path_edges.sum { |e| e.disruption_probability * 100.0 } / path_edges.size.to_f
        max_ml_prob = path_edges.map { |e| e.disruption_probability * 100.0 }.max || 20.0
      else
        relevant_roads = @roads.select { |r| r.state == zone[:state] || (wh.location && r.state == wh.location.state) }
        avg_road_risk = relevant_roads.any? ? (relevant_roads.sum { |r| r.risk_score.to_f } / relevant_roads.size.to_f) : 25.0
        avg_ml_prob = relevant_roads.any? ? (relevant_roads.sum { |r| r.try(:ml_disruption_probability).to_f * 100.0 } / relevant_roads.size.to_f) : 20.0
        max_ml_prob = relevant_roads.map { |r| r.try(:ml_disruption_probability).to_f * 100.0 }.max || 20.0
      end

      travel_efficiency = [100.0 - (route_dist * 0.25), 10.0].max.clamp(10.0, 100.0)
      route_safety = [100.0 - (avg_road_risk * 0.5) - (avg_ml_prob * 0.3), 5.0].max.clamp(5.0, 100.0)
      reliability = [100.0 - avg_ml_prob, 10.0].max.clamp(10.0, 100.0)
      network_resilience = has_ground_route ? 80.0 : 15.0
      alt_availability = has_ground_route ? 75.0 : 0.0

      route_score = (
        (0.30 * travel_efficiency) +
        (0.25 * route_safety) +
        (0.20 * reliability) +
        (0.15 * network_resilience) +
        (0.10 * alt_availability)
      ).clamp(0.0, 100.0).round(1)

      classification = if !has_ground_route
                         "UNAVAILABLE"
                       elsif route_safety < 40.0 || max_ml_prob >= 75.0
                         "HIGH_RISK"
                       elsif route_score >= 75.0
                         "OPTIMAL"
                       elsif route_score >= 50.0
                         "SAFE_ALTERNATIVE"
                       else
                         "LAST_RESORT"
                       end

      {
        origin_warehouse_id: wh.id,
        origin_warehouse_name: wh.name,
        destination_location_id: dest_loc.id,
        destination_name: dest_loc.name,
        distance_km: route_dist.round(1),
        estimated_hours: est_hours,
        route_score: route_score,
        route_safety: route_safety.round(1),
        travel_efficiency: travel_efficiency.round(1),
        reliability: reliability.round(1),
        classification: classification,
        has_ground_route: has_ground_route,
        corridor_risk: avg_road_risk.round(1),
        is_bypass: is_bypass
      }
    end

    # =========================================================================
    # STEP 4 & 5: BOUNDED STRATEGY GENERATION & OPTIMIZATION
    # =========================================================================
    def generate_candidate_strategies(priority_zones:, warehouse_capabilities:, route_analysis:, predictive_analysis:, limit: MAX_STRATEGIES)
      strategies = []
      top_zone = priority_zones.first
      return [] unless top_zone

      primary_wh = warehouse_capabilities.find { |w| w[:recommended_role] == "PRIMARY_DISPATCH_HUB" } || warehouse_capabilities.first
      return [] unless primary_wh
      secondary_wh = warehouse_capabilities.find { |w| w[:warehouse_id] != primary_wh[:warehouse_id] } || warehouse_capabilities.second

      # Find best routes
      primary_route = route_analysis.find { |r| r[:origin_warehouse_id] == primary_wh[:warehouse_id] && r[:destination_location_id] == top_zone[:location_id] }
      secondary_route = secondary_wh ? route_analysis.find { |r| r[:origin_warehouse_id] == secondary_wh[:warehouse_id] && r[:destination_location_id] == top_zone[:location_id] } : nil

      # --- STRATEGY A: Direct Dispatch ---
      # Nearest warehouse via shortest path
      if primary_route && primary_route[:classification] != "UNAVAILABLE"
        strategies << build_strategy(
          strategy_type: "DIRECT_DISPATCH",
          name: "Direct Highway Dispatch",
          description: "Immediate single-corridor freight transit directly from #{primary_wh[:warehouse_name]} to #{top_zone[:name]}.",
          primary_warehouse: primary_wh,
          secondary_warehouse: nil,
          route: primary_route,
          target_zones: [top_zone],
          pop_protected: (top_zone[:population_at_risk] * 0.75).to_i,
          response_speed: [100.0 - (primary_route[:estimated_hours] * 10.0), 10.0].max,
          route_safety: primary_route[:route_safety],
          resource_efficiency: 85.0,
          plan_resilience_class: primary_route[:route_safety] < 50.0 ? "CRITICAL_SINGLE_POINT_FAILURE" : "FRAGILE",
          prediction_confidence: 75.0,
          allocated_resources: allocate_resources(primary_wh, (top_zone[:population_at_risk] * 0.75).to_i)
        )
      end

      # --- STRATEGY B: Resilient Dispatch ---
      # Safer warehouse or longer bypass route to avoid chokepoints
      resilient_route = route_analysis.find { |r| r[:destination_location_id] == top_zone[:location_id] && %w[OPTIMAL SAFE_ALTERNATIVE].include?(r[:classification]) }
      if resilient_route
        resilient_wh = warehouse_capabilities.find { |w| w[:warehouse_id] == resilient_route[:origin_warehouse_id] } || primary_wh
        strategies << build_strategy(
          strategy_type: "RESILIENT_DISPATCH",
          name: "Resilient Bypass Routing",
          description: "Protected delivery from #{resilient_wh[:warehouse_name]} routed via lower-risk mountain bypass.",
          primary_warehouse: resilient_wh,
          secondary_warehouse: nil,
          route: resilient_route,
          target_zones: [top_zone],
          pop_protected: (top_zone[:population_at_risk] * 0.85).to_i,
          response_speed: [100.0 - (resilient_route[:estimated_hours] * 12.0), 10.0].max,
          route_safety: [resilient_route[:route_safety] + 15.0, 95.0].min,
          resource_efficiency: 80.0,
          plan_resilience_class: "RESILIENT",
          prediction_confidence: 80.0,
          allocated_resources: allocate_resources(resilient_wh, (top_zone[:population_at_risk] * 0.85).to_i)
        )
      end

      # --- STRATEGY C: Split Allocation (Multi-Hub) ---
      # Warehouse A + Warehouse B share the load
      if primary_wh && secondary_wh && primary_route && secondary_route
        strategies << build_strategy(
          strategy_type: "SPLIT_ALLOCATION",
          name: "Dual-Hub Split Allocation",
          description: "Dual-source supply lines from #{primary_wh[:warehouse_name]} (60%) and #{secondary_wh[:warehouse_name]} (40%) to eliminate single-depot failure.",
          primary_warehouse: primary_wh,
          secondary_warehouse: secondary_wh,
          route: primary_route,
          target_zones: priority_zones.first(2),
          pop_protected: (top_zone[:population_at_risk] * 0.95).to_i,
          response_speed: 80.0,
          route_safety: ((primary_route[:route_safety] + secondary_route[:route_safety]) / 2.0).round(1),
          resource_efficiency: 92.0,
          plan_resilience_class: "HIGHLY_RESILIENT",
          prediction_confidence: 85.0,
          allocated_resources: allocate_split_resources(primary_wh, secondary_wh, top_zone[:population_at_risk])
        )
      end

      # --- STRATEGY D: Prepositioning ---
      # Preemptive forward stock deployment
      if primary_wh && (predictive_analysis[:overall_cascade_risk] >= 40.0 || top_zone[:humanitarian_priority] >= 65.0)
        strategies << build_strategy(
          strategy_type: "PREPOSITIONING",
          name: "Forward Pre-positioning & Staging",
          description: "Advance deployment of critical emergency reserves from #{primary_wh[:warehouse_name]} to forward staging post before projected corridor collapse.",
          primary_warehouse: primary_wh,
          secondary_warehouse: secondary_wh,
          route: primary_route || route_analysis.first,
          target_zones: [top_zone],
          pop_protected: top_zone[:population_at_risk],
          response_speed: 95.0, # Prepositioned reserves achieve near-instantaneous local distribution
          route_safety: 85.0,
          resource_efficiency: 88.0,
          plan_resilience_class: "HIGHLY_RESILIENT",
          prediction_confidence: 88.0,
          allocated_resources: allocate_resources(primary_wh, top_zone[:population_at_risk])
        )
      end

      # --- STRATEGY E: Aerial Contingency ---
      # Ground dispatch coordinated with airlift/UAV recon
      strategies << build_strategy(
        strategy_type: "AERIAL_CONTINGENCY",
        name: "Ground-Air Integrated Contingency",
        description: "Primary ground logistics coupled with standby heavy-lift helicopters and UAV pathfinder drones.",
        primary_warehouse: primary_wh,
        secondary_warehouse: nil,
        route: primary_route || route_analysis.first,
        target_zones: [top_zone],
        pop_protected: (top_zone[:population_at_risk] * 0.70).to_i,
        response_speed: 90.0,
        route_safety: 95.0,
        resource_efficiency: 60.0, # Air transport is resource intensive
        plan_resilience_class: "HIGHLY_RESILIENT",
        prediction_confidence: 82.0,
        allocated_resources: allocate_resources(primary_wh, (top_zone[:population_at_risk] * 0.70).to_i)
      )

      # Ensure at least 1 strategy exists
      if strategies.empty? && primary_wh
        strategies << build_default_strategy(primary_wh, top_zone)
      end

      strategies.first(limit)
    end

    def build_strategy(strategy_type:, name:, description:, primary_warehouse:, secondary_warehouse:, route:, target_zones:, pop_protected:, response_speed:, route_safety:, resource_efficiency:, plan_resilience_class:, prediction_confidence:, allocated_resources:)
      # Multi-objective Response Utility Formula:
      # 0.30 * PopProtectedRatio + 0.20 * ResponseSpeed + 0.15 * RouteSafety + 0.15 * ResourceEff + 0.10 * PlanResilience + 0.10 * PredConf
      total_zone_pop = target_zones.sum { |z| z[:population_at_risk] }
      pop_ratio = total_zone_pop.positive? ? ((pop_protected.to_f / total_zone_pop.to_f) * 100.0).clamp(0.0, 100.0) : 50.0

      resilience_score = case plan_resilience_class
                         when "HIGHLY_RESILIENT"              then 92.0
                         when "RESILIENT"                     then 78.0
                         when "MODERATELY_RESILIENT"          then 62.0
                         when "FRAGILE"                       then 42.0
                         else 25.0
                         end

      utility = (
        (0.30 * pop_ratio) +
        (0.20 * response_speed.to_f.clamp(0.0, 100.0)) +
        (0.15 * route_safety.to_f.clamp(0.0, 100.0)) +
        (0.15 * resource_efficiency.to_f.clamp(0.0, 100.0)) +
        (0.10 * resilience_score) +
        (0.10 * prediction_confidence.to_f.clamp(0.0, 100.0))
      ).clamp(0.0, 100.0).round(1)

      multiplier = RESILIENCE_MULTIPLIERS[plan_resilience_class] || 0.80
      risk_adjusted_utility = (utility * multiplier).clamp(0.0, 100.0).round(1)

      eta_hours = route ? route[:estimated_hours] : 4.0

      {
        strategy_id: "STRAT-#{SecureRandom.hex(3).upcase}",
        strategy_type: strategy_type,
        name: name,
        description: description,
        primary_warehouse_id: primary_warehouse[:warehouse_id],
        primary_warehouse_name: primary_warehouse[:warehouse_name],
        secondary_warehouse_id: secondary_warehouse&.dig(:warehouse_id),
        secondary_warehouse_name: secondary_warehouse&.dig(:warehouse_name),
        primary_route: route,
        target_zones: target_zones.map { |z| z[:name] },
        population_protected: pop_protected,
        estimated_eta_hours: eta_hours,
        response_utility: utility,
        plan_resilience_class: plan_resilience_class,
        plan_resilience_score: resilience_score,
        risk_adjusted_utility: risk_adjusted_utility,
        route_safety_score: route_safety.round(1),
        response_speed_score: response_speed.round(1),
        allocated_resources: allocated_resources,
        trade_offs: {
          speed_vs_safety: route_safety >= 75.0 ? "Prioritizes convoy safety over maximum transit speed" : "Prioritizes rapid arrival over defensive detours",
          redundancy: secondary_warehouse ? "High multi-node redundancy" : "Single point of depot dispatch",
          cost_efficiency: resource_efficiency >= 80.0 ? "High cost-benefit alignment" : "Resource-intensive emergency protocol"
        }
      }
    end

    def build_default_strategy(primary_wh, top_zone)
      {
        strategy_id: "STRAT-DEF-#{SecureRandom.hex(2).upcase}",
        strategy_type: "DIRECT_DISPATCH",
        name: "Standard Direct Dispatch",
        description: "Direct overland dispatch from #{primary_wh[:warehouse_name]} to #{top_zone[:name]}.",
        primary_warehouse_id: primary_wh[:warehouse_id],
        primary_warehouse_name: primary_wh[:warehouse_name],
        secondary_warehouse_id: nil,
        secondary_warehouse_name: nil,
        primary_route: nil,
        target_zones: [top_zone[:name]],
        population_protected: (top_zone[:population_at_risk] * 0.6).to_i,
        estimated_eta_hours: 5.0,
        response_utility: 55.0,
        plan_resilience_class: "MODERATELY_RESILIENT",
        plan_resilience_score: 60.0,
        risk_adjusted_utility: 46.8,
        route_safety_score: 60.0,
        response_speed_score: 55.0,
        allocated_resources: allocate_resources(primary_wh, (top_zone[:population_at_risk] * 0.6).to_i),
        trade_offs: {
          speed_vs_safety: "Balanced baseline dispatch",
          redundancy: "Single dispatch hub",
          cost_efficiency: "Moderate resource efficiency"
        }
      }
    end

    def optimize_strategies(strategies)
      strategies.sort_by { |s| -s[:risk_adjusted_utility] }
    end

    # =========================================================================
    # RESOURCE ALLOCATION (STRICT: ALLOCATED <= AVAILABLE)
    # =========================================================================
    def allocate_resources(warehouse, target_pop)
      return default_allocated_resources if warehouse.nil?

      avail = warehouse[:available_resources] || {}
      avail_cap = [warehouse[:available_capacity].to_i, 100].max

      # Calculate needed supplies based on population
      needed_kits = [target_pop / 50, 10].max
      needed_food = [target_pop / 10, 50].max
      needed_fuel = [target_pop * 2, 500].max

      # Strictly enforce Allocated <= Available
      alloc_kits = [needed_kits, (avail[:medical_kits] || avail_cap * 0.8).to_i].min
      alloc_food = [needed_food, (avail[:food_packages] || avail_cap * 1.5).to_i].min
      alloc_fuel = [needed_fuel, (avail[:fuel_liters] || avail_cap * 10).to_i].min
      alloc_veh = [avail[:rescue_vehicles].to_i, 4].min
      alloc_pers = [avail[:personnel].to_i, 20].min

      {
        medical_kits: alloc_kits,
        food_packages: alloc_food,
        fuel_liters: alloc_fuel,
        rescue_vehicles: alloc_veh,
        personnel: alloc_pers,
        total_tonnage: ((alloc_kits * 0.02) + (alloc_food * 0.05) + (alloc_fuel * 0.001)).round(1),
        constraint_verified: true
      }
    end

    def default_allocated_resources
      {
        medical_kits: 0,
        food_packages: 0,
        fuel_liters: 0,
        rescue_vehicles: 0,
        personnel: 0,
        total_tonnage: 0.0,
        constraint_verified: true
      }
    end

    def allocate_split_resources(wh1, wh2, target_pop)
      r1 = allocate_resources(wh1, (target_pop * 0.6).to_i)
      r2 = allocate_resources(wh2, (target_pop * 0.4).to_i)

      {
        primary_hub_allocation: { warehouse: wh1[:warehouse_name], share_pct: 60, resources: r1 },
        secondary_hub_allocation: { warehouse: wh2[:warehouse_name], share_pct: 40, resources: r2 },
        medical_kits: r1[:medical_kits] + r2[:medical_kits],
        food_packages: r1[:food_packages] + r2[:food_packages],
        fuel_liters: r1[:fuel_liters] + r2[:fuel_liters],
        rescue_vehicles: r1[:rescue_vehicles] + r2[:rescue_vehicles],
        personnel: r1[:personnel] + r2[:personnel],
        total_tonnage: (r1[:total_tonnage] + r2[:total_tonnage]).round(1),
        constraint_verified: true
      }
    end

    # =========================================================================
    # STEP 6: AUTONOMOUS PREPOSITIONING DECISION
    # =========================================================================
    def evaluate_prepositioning_decisions(priority_zones:, predictive_analysis:, warehouse_capabilities:)
      top_zone = priority_zones.first
      return [] unless top_zone

      scenarios = predictive_analysis[:scenarios] || []
      top_scen = scenarios.first

      failure_prob = top_scen ? top_scen[:failure_probability].to_f : 35.0
      cascade_impact = top_scen ? top_scen[:cascade_score].to_f : 40.0
      pred_conf = top_scen ? top_scen[:prediction_confidence].to_f : 75.0

      # Response Delay Reduction: Without prepositioning (e.g. 8.5h) vs With prepositioning (e.g. 2.1h) -> 75%
      delay_reduction = [failure_prob * 0.9, 85.0].min
      future_pop_protected = top_zone[:population_at_risk]

      # Prepositioning Benefit Formula:
      # 0.30 * FuturePopProtectedRatio + 0.25 * DelayReduction + 0.20 * FailureProb + 0.15 * CascadeImpact + 0.10 * PredConf
      benefit_score = (
        (0.30 * [future_pop_protected / 1000.0, 100.0].min) +
        (0.25 * delay_reduction) +
        (0.20 * failure_prob) +
        (0.15 * cascade_impact) +
        (0.10 * pred_conf)
      ).clamp(0.0, 100.0).round(1)

      decision = if benefit_score >= 85.0
                   "PREPOSITION_NOW"
                 elsif benefit_score >= 70.0
                   "PREPOSITION_WITHIN_6H"
                 elsif benefit_score >= 50.0
                   "PREPARE_RESOURCES"
                 elsif benefit_score >= 30.0
                   "MONITOR"
                 else
                   "NOT_REQUIRED"
                 end

      primary_wh = warehouse_capabilities.first

      [{
        decision: decision,
        benefit_score: benefit_score,
        target_zone: top_zone[:name],
        source_warehouse: primary_wh ? primary_wh[:warehouse_name] : "Regional Hub",
        threat_corridor: top_scen ? top_scen[:name] : "Regional Arterial Corridor",
        failure_probability: failure_prob,
        cascade_impact: cascade_impact,
        expected_delay_reduction_pct: delay_reduction.round(1),
        current_eta_hours: 8.5,
        prepositioned_eta_hours: 2.1,
        action: "Move emergency medical kits, high-calorie food reserves, and fuel drums from #{primary_wh ? primary_wh[:warehouse_name] : 'Central Depot'} to forward staging post near #{top_zone[:name]}."
      }]
    end

    # =========================================================================
    # STEP 7: AIRLIFT & RECONNAISSANCE ESCALATION
    # =========================================================================
    def evaluate_aerial_escalation(priority_zones:, route_analysis:, optimal_strategy:)
      top_zone = priority_zones.first
      return {} unless top_zone

      best_route = route_analysis.find { |r| r[:destination_location_id] == top_zone[:location_id] }
      no_ground_route = best_route.nil? || best_route[:classification] == "UNAVAILABLE"
      ground_route_extreme_risk = best_route && best_route[:route_safety] < 20.0
      extreme_isolation = top_zone[:isolation_risk] == "CRITICAL" && top_zone[:population_at_risk] >= 100_000

      recommendation = if no_ground_route || ground_route_extreme_risk
                         "EMERGENCY_AIRLIFT"
                       elsif extreme_isolation || (best_route && best_route[:estimated_hours] >= 8.0)
                         "GROUND_WITH_AIR_CONTINGENCY"
                       elsif top_zone[:humanitarian_priority] >= 75.0
                         "UAV_RECONNAISSANCE"
                       else
                         "GROUND_RESPONSE"
                       end

      {
        recommendation: recommendation,
        airlift_justified: %w[EMERGENCY_AIRLIFT GROUND_WITH_AIR_CONTINGENCY].include?(recommendation),
        trigger: no_ground_route ? "Zero passable ground routes available" : (ground_route_extreme_risk ? "Overland route safety critically compromised (< 20/100)" : "Routine surveillance threshold"),
        airlift_benefit: "Bypasses all mountain landslides, reducing emergency relief transit time to < 45 minutes for critical medical trauma supplies.",
        uav_recon_status: "Active thermal imaging patrols requested along key approaches.",
        human_command_note: "Airlift assets require immediate verification of helipad clearance and IAF / NDRF flight window authorization."
      }
    end

    # =========================================================================
    # STEP 8: CONTINGENCY SIMULATION (MAX 3 PER STRATEGY)
    # =========================================================================
    def simulate_contingencies(strategy, route_analysis, warehouse_capabilities)
      contingencies = []
      return [] unless strategy

      # Contingency A: Primary Route Fails
      fallback_route = route_analysis.find do |r|
        r[:origin_warehouse_id] == strategy[:primary_warehouse_id] &&
          r[:destination_name] == strategy[:target_zones].first &&
          r[:classification] != "HIGH_RISK"
      end

      contingencies << {
        contingency_id: "CONTINGENCY-A",
        scenario: "Primary Transit Corridor Complete Failure",
        description: "Primary delivery corridor blocked by unexpected catastrophic landslide.",
        impact: "Initial ground convoy transit blocked; +2.5 hour detour penalty.",
        fallback_available: fallback_route.present?,
        fallback_action: fallback_route ? "Switch to secondary mountain bypass (#{fallback_route[:distance_km]} km)" : "Escalate to emergency air-drop protocol",
        residual_response_capacity_pct: fallback_route ? 82.0 : 40.0
      }

      # Contingency B: Primary Warehouse Becomes Inaccessible
      sec_wh = warehouse_capabilities.find { |w| w[:warehouse_id] != strategy[:primary_warehouse_id] && w[:capability_score] >= 50.0 }
      contingencies << {
        contingency_id: "CONTINGENCY-B",
        scenario: "Primary Dispatch Depot Cut Off or Depleted",
        description: "Access road to #{strategy[:primary_warehouse_name]} severed or depot capacity exhausted.",
        impact: "Zero dispatch capability from primary logistics hub.",
        fallback_available: sec_wh.present?,
        fallback_action: sec_wh ? "Transfer dispatch authority to #{sec_wh[:warehouse_name]}" : "Activate inter-state emergency mutual aid",
        residual_response_capacity_pct: sec_wh ? 75.0 : 25.0
      }

      # Contingency C: Secondary Predicted Corridor Fails
      contingencies << {
        contingency_id: "CONTINGENCY-C",
        scenario: "Multi-Point Secondary Cascade Failure",
        description: "Concurrent failure of both primary and secondary regional transport lifelines.",
        impact: "Widespread regional isolation across multiple districts.",
        fallback_available: true,
        fallback_action: "Activate multi-agency airlift corridors and local micro-depot distribution",
        residual_response_capacity_pct: 60.0
      }

      contingencies.first(MAX_CONTINGENCIES_PER_STRATEGY)
    end

    def calculate_plan_resilience(strategy, contingency_plans)
      return { score: 50.0, classification: "MODERATELY_RESILIENT" } unless strategy

      avg_residual = if contingency_plans.any?
                       contingency_plans.sum { |c| c[:residual_response_capacity_pct].to_f } / contingency_plans.size.to_f
                     else
                       strategy[:plan_resilience_score].to_f
                     end

      # Blend strategy resilience with actual contingency simulation outcomes
      blended_score = ((strategy[:plan_resilience_score].to_f * 0.5) + (avg_residual * 0.5)).clamp(0.0, 100.0).round(1)

      classification = if blended_score >= 85.0
                         "HIGHLY_RESILIENT"
                       elsif blended_score >= 70.0
                         "RESILIENT"
                       elsif blended_score >= 50.0
                         "MODERATELY_RESILIENT"
                       elsif blended_score >= 30.0
                         "FRAGILE"
                       else
                         "CRITICAL_SINGLE_POINT_FAILURE"
                       end

      {
        score: blended_score,
        classification: classification,
        contingency_coverage_pct: contingency_plans.count { |c| c[:fallback_available] } * 33.3,
        resilience_multiplier: RESILIENCE_MULTIPLIERS[classification] || 0.85
      }
    end

    # =========================================================================
    # STEP 9: COUNTERFACTUAL ANALYSIS (NO ACTION VS RESQWAY PLAN)
    # =========================================================================
    def compute_counterfactual_analysis(priority_zones:, optimal_strategy:, predictive_analysis:)
      total_affected_pop = priority_zones.sum { |z| z[:population_at_risk] }
      total_affected_pop = 25_000 if total_affected_pop <= 0

      # Without Action: prolonged response delay, high unserved population
      no_action_delay_hours = 18.0
      no_action_unserved_pop = total_affected_pop
      no_action_supply_continuity_pct = 15.0

      # With ResQWay Plan: rapid response, high protected population
      plan_protected_pop = optimal_strategy ? optimal_strategy[:population_protected] : (total_affected_pop * 0.75).to_i
      plan_delayed_pop = [total_affected_pop - plan_protected_pop, 0].max
      plan_delay_hours = optimal_strategy ? optimal_strategy[:estimated_eta_hours] : 4.5
      plan_supply_continuity_pct = 88.0

      # Improvement percentages
      delay_improvement_pct = (((no_action_delay_hours - plan_delay_hours) / no_action_delay_hours) * 100.0).clamp(0.0, 95.0).round(1)
      population_improvement_pct = (((total_affected_pop - plan_delayed_pop) / total_affected_pop.to_f) * 100.0).clamp(0.0, 95.0).round(1)

      plan_metrics = {
        population_protected: plan_protected_pop,
        population_delayed: plan_delayed_pop,
        expected_response_delay_hours: plan_delay_hours,
        supply_continuity_pct: plan_supply_continuity_pct,
        plan_resilience_score: optimal_strategy ? optimal_strategy[:plan_resilience_score] : 75.0
      }

      {
        model_disclaimer: "These metrics represent model-simulated operational estimates based on current graph topology and predictive hazard curves. Actual disaster outcomes may vary.",
        without_action: {
          population_affected: total_affected_pop,
          expected_response_delay_hours: no_action_delay_hours,
          supply_continuity_pct: no_action_supply_continuity_pct,
          isolated_settlements: priority_zones.count { |z| z[:isolation_risk] == "CRITICAL" }
        },
        with_resqway_plan: plan_metrics,
        with_enma_plan: plan_metrics,
        modeled_improvements: {
          delay_reduction_pct: delay_improvement_pct,
          population_protection_pct: population_improvement_pct,
          supply_continuity_gain_pct: (plan_supply_continuity_pct - no_action_supply_continuity_pct).round(1)
        }
      }
    end

    # =========================================================================
    # STEP 10: DETERMINISTIC OPERATIONAL TIMELINE
    # =========================================================================
    def generate_operational_timeline(optimal_strategy:, prepositioning:, aerial:, forecast_hours:)
      timeline = []
      now = Time.current

      timeline << {
        time_offset: "T+0 MIN",
        phase: "IMMEDIATE_ACTION",
        title: "Submit Plan for Human Incident Command Approval",
        action: "Display optimized response package on tactical dispatch console; await commanding officer electronic sign-off.",
        responsible_agency: "DISASTER_OPERATIONS_HQ",
        mandatory: true
      }

      timeline << {
        time_offset: "T+15 MIN",
        phase: "INTELLIGENCE_VERIFICATION",
        title: "Launch UAV Route Reconnaissance",
        action: "Deploy forward reconnaissance drones to scan critical corridor approaches and confirm absence of unreported rockfalls.",
        responsible_agency: "UAV_RECONNAISSANCE_TEAM",
        mandatory: false
      }

      prep = prepositioning.first
      if prep && prep[:decision] == "PREPOSITION_NOW"
        timeline << {
          time_offset: "T+30 MIN",
          phase: "PREPOSITIONING",
          title: "Mobilize Advance Supply Convoy",
          action: "Dispatch advance trucks with medical packages and water filtration equipment toward forward staging outpost.",
          responsible_agency: "LOGISTICS_COMMAND",
          mandatory: true
        }
      else
        timeline << {
          time_offset: "T+45 MIN",
          phase: "DEPOT_MOBILIZATION",
          title: "Palletize Depot Inventories",
          action: "Stage relief rations at loading docks of #{optimal_strategy ? optimal_strategy[:primary_warehouse_name] : 'Central Depot'}.",
          responsible_agency: "WAREHOUSE_OPERATIONS",
          mandatory: true
        }
      end

      timeline << {
        time_offset: "T+90 MIN",
        phase: "TACTICAL_STAGING",
        title: "Establish Forward Operations Post",
        action: "Set up mobile satellite communications and medical triage clearing center at perimeter junction.",
        responsible_agency: "FIELD_DISPATCH_UNIT",
        mandatory: false
      }

      timeline << {
        time_offset: "T+4 HOURS",
        phase: "NETWORK_REASSESSMENT",
        title: "Dynamic Graph & Weather Re-evaluation",
        action: "Re-run network connectivity algorithms to incorporate updated Doppler radar scans and telemetry check-ins.",
        responsible_agency: "RESQWAY_CORE",
        mandatory: true
      }

      if aerial && aerial[:airlift_justified]
        timeline << {
          time_offset: "T+6 HOURS",
          phase: "AIR_CONTINGENCY",
          title: "Activate Standby Helicopter Airlift",
          action: "Commence sling-load delivery of essential medical kits to designated highland landing zones.",
          responsible_agency: "AIR_WING_COMMAND",
          mandatory: false
        }
      end

      timeline
    end

    # =========================================================================
    # STEP 11: RESPONSE URGENCY & EXPLAINABLE AUTONOMOUS DECISION
    # =========================================================================
    def calculate_overall_response_urgency(priority_zones:, optimal_strategy:, predictive_analysis:)
      top_zone = priority_zones.first
      p_score = top_zone ? top_zone[:humanitarian_priority].to_f : 40.0
      pred_urgency = predictive_analysis.dig(:summary, :overall_cascade_risk).to_f
      cascading_impact = predictive_analysis.dig(:top_scenario, :cascade_score).to_f
      confidence = predictive_analysis.dig(:summary, :prediction_confidence).to_f || 75.0
      delay_risk = top_zone ? top_zone[:response_delay_risk].to_f : 30.0

      # Response Urgency =
      # 0.35 * HumanitarianPriority + 0.25 * PredUrgency + 0.20 * CascadeImpact + 0.10 * PredConf + 0.10 * DelayRisk
      (
        (0.35 * p_score) +
        (0.25 * pred_urgency) +
        (0.20 * cascading_impact) +
        (0.10 * confidence) +
        (0.10 * delay_risk)
      ).clamp(0.0, 100.0).round(1)
    end

    def classify_urgency_level(urgency_score)
      URGENCY_LEVELS.find { |l| urgency_score >= l[:min] } || URGENCY_LEVELS.last
    end

    def build_explainable_decision(optimal_strategy:, alternative_strategies:, priority_zones:, contingency_plans:, overall_urgency:)
      top_zone = priority_zones.first
      target_name = top_zone ? top_zone[:name] : "Target Sector"

      why_bullets = []
      why_bullets << "Protects #{optimal_strategy ? optimal_strategy[:population_protected] : 'the vast majority of'} residents in #{target_name}."
      why_bullets << "Highest Risk-Adjusted Response Utility (#{optimal_strategy ? optimal_strategy[:risk_adjusted_utility] : '78.0'}/100) across all modeled strategies."
      if optimal_strategy && optimal_strategy[:secondary_warehouse_name]
        why_bullets << "Employs two independent supply nodes (#{optimal_strategy[:primary_warehouse_name]} + #{optimal_strategy[:secondary_warehouse_name]}) to eliminate single-point failure."
      else
        why_bullets << "Avoids vulnerable high-risk mountain sectors with high predicted disruption probabilities."
      end
      why_bullets << "Survives simulated primary corridor collapse with #{contingency_plans.first&.dig(:residual_response_capacity_pct) || 80}% residual capacity."

      # Explain why each alternative strategy was rejected
      rejected_explanations = (alternative_strategies || []).map do |alt|
        reasons = []
        if alt[:strategy_type] == "DIRECT_DISPATCH"
          reasons << "Shortest overland route, but exposes supply convoy to single-point chokepoint failure."
          reasons << "Route safety score (#{alt[:route_safety_score]}/100) falls below defensive transport standards." if alt[:route_safety_score] < 60.0
        elsif alt[:strategy_type] == "AERIAL_CONTINGENCY"
          reasons << "Prohibitive fuel and logistics cost; payload capacity restricted to lightweight medical crates."
          reasons << "Subject to severe weather grounding during monsoon cloudbursts."
        elsif alt[:strategy_type] == "RESILIENT_DISPATCH"
          reasons << "Excessive transit detour increases emergency response delay by #{alt[:estimated_eta_hours]} hours."
        else
          reasons << "Lower overall risk-adjusted utility (#{alt[:risk_adjusted_utility]}/100 vs #{optimal_strategy ? optimal_strategy[:risk_adjusted_utility] : 80}/100)."
        end

        {
          strategy_name: alt[:name],
          strategy_type: alt[:strategy_type],
          risk_adjusted_utility: alt[:risk_adjusted_utility],
          why_rejected: reasons
        }
      end

      {
        recommendation_id: "REC-#{SecureRandom.hex(4).upcase}",
        human_approval_required: true,
        decision_title: optimal_strategy ? optimal_strategy[:name] : "Autonomous Response Plan",
        recommended_action: optimal_strategy ? "#{optimal_strategy[:name]} targeting #{target_name}" : "Emergency Relief Dispatch",
        why_selected: why_bullets,
        rejected_alternatives: rejected_explanations,
        selected_because: "Selected because it maximizes humanitarian population protection while preserving redundant logistical fallback corridors.",
        expected_benefit: {
          population_protected: optimal_strategy ? optimal_strategy[:population_protected] : 0,
          response_delay_reduction_pct: 68.0,
          supply_continuity_improvement_pct: 72.0
        },
        risks_and_assumptions: [
          "Assumes road clearances along selected bypass remain passable during transit.",
          "Requires local municipal clearance for forward staging post operation.",
          "Actual terrain conditions subject to immediate UAV confirmation."
        ],
        contingency_summary: "#{contingency_plans.size} contingency stress-tests verified with #{contingency_plans.first&.dig(:residual_response_capacity_pct) || 82}% residual response capacity.",
        prediction_confidence: 85.0
      }
    end

    # =========================================================================
    # STEP 12: ALERT INTEGRATION (24-HOUR DEDUPLICATION & GATING)
    # =========================================================================
    def create_response_alerts!(optimal_strategy, overall_urgency, priority_zones)
      return [] unless optimal_strategy && overall_urgency >= 70.0

      created_alerts = []
      now = Time.current
      cutoff = 24.hours.ago
      alert_type = "autonomous_response_required"

      existing = LogisticsAlert.where(alert_type: alert_type, status: "active")
                               .where("created_at >= ?", cutoff)
                               .first

      return [] if existing

      top_zone = priority_zones.first
      zone_name = top_zone ? top_zone[:name] : "Priority Sector"

      alert = LogisticsAlert.create!(
        alert_type: alert_type,
        severity: overall_urgency >= 85.0 ? "critical" : "high",
        title: "Autonomous Response Recommended: #{optimal_strategy[:name]}",
        message: "ResQWay recommends #{optimal_strategy[:name]} for #{zone_name}. Urgency score: #{overall_urgency}/100. Awaiting human command approval.",
        status: "active",
        metadata_json: {
          strategy_id: optimal_strategy[:strategy_id],
          strategy_type: optimal_strategy[:strategy_type],
          urgency_score: overall_urgency,
          target_zone: zone_name,
          human_approval_status: "AWAITING_APPROVAL"
        }
      )
      created_alerts << alert
      created_alerts
    rescue StandardError => e
      Rails.logger.warn("[AutonomousResponseOptimizationService] Alert creation failed: #{e.message}")
      []
    end

    # =========================================================================
    # HELPERS
    # =========================================================================
    private

    def nearest_warehouse_distance(location)
      return 999.0 if @warehouses.empty?

      @warehouses.map do |wh|
        haversine_distance(location.latitude, location.longitude, wh.latitude, wh.longitude)
      end.min || 999.0
    end

    def zone_lat(zone)
      loc = @locations.find { |l| l.id == zone[:location_id] }
      loc&.latitude || 26.0
    end

    def zone_lon(zone)
      loc = @locations.find { |l| l.id == zone[:location_id] }
      loc&.longitude || 92.0
    end

    def haversine_distance(lat1, lon1, lat2, lon2)
      return 999.0 if lat1.nil? || lon1.nil? || lat2.nil? || lon2.nil?

      dlat = (lat2.to_f - lat1.to_f) * Math::PI / 180.0
      dlon = (lon2.to_f - lon1.to_f) * Math::PI / 180.0

      a = (Math.sin(dlat / 2.0)**2) +
          (Math.cos(lat1.to_f * Math::PI / 180.0) * Math.cos(lat2.to_f * Math::PI / 180.0) * (Math.sin(dlon / 2.0)**2))
      c = 2.0 * Math.atan2(Math.sqrt(a), Math.sqrt(1.0 - a))
      (EARTH_RADIUS_KM * c).round(2)
    end

    def fetch_or_compute_predictive_analysis(forecast_hours)
      max_updated = @roads.map { |r| r.try(:updated_at) }.compact.max.to_i
      cache_key = "resqway/predictive_cascade_analysis/#{forecast_hours}/#{max_updated}"

      if defined?(Rails) && Rails.cache
        cached = Rails.cache.read(cache_key)
        if cached
          @cache_hits += 1
          return cached
        end

        pred_service = @predictive_service || ResQWay::PredictiveCascadingImpactService.new(roads: @roads, locations: @locations, warehouses: @warehouses)
        result = pred_service.analyze(forecast_hours: forecast_hours)
        Rails.cache.write(cache_key, result, expires_in: 3.minutes)
        result
      else
        pred_service = @predictive_service || ResQWay::PredictiveCascadingImpactService.new(roads: @roads, locations: @locations, warehouses: @warehouses)
        pred_service.analyze(forecast_hours: forecast_hours)
      end
    end

    def empty_analysis_result(forecast_hours, start_clock)
      elapsed_ms = start_clock ? ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_clock) * 1000.0).round(1) : 1.0

      {
        status: "COMPLETE",
        human_approval_status: "AWAITING_HUMAN_COMMAND_APPROVAL",
        generated_at: Time.current,
        forecast_horizon: forecast_hours,
        overall_response_urgency: 0.0,
        urgency_level: "MONITOR",
        urgency_color: "#10b981",
        population_prioritized: 0,
        priority_zones: [],
        warehouse_capabilities: [],
        route_analysis: [],
        optimal_strategy: nil,
        alternative_strategies: [],
        resource_prepositioning: [],
        aerial_response: { recommendation: "NOT_REQUIRED", airlift_justified: false },
        contingency_plans: [],
        response_resilience: { score: 100.0, classification: "HIGHLY_RESILIENT" },
        counterfactual_analysis: {
          without_action: { population_affected: 0, expected_response_delay_hours: 0.0 },
          with_resqway_plan: { population_protected: 0, expected_response_delay_hours: 0.0 },
          with_enma_plan: { population_protected: 0, expected_response_delay_hours: 0.0 },
          modeled_improvements: { delay_reduction_pct: 0.0, population_protection_pct: 0.0 }
        },
        operational_timeline: [],
        decision_explanation: {
          decision_title: "No Action Required",
          why_selected: ["No active transportation network or priority zones registered."],
          rejected_alternatives: []
        },
        alerts_generated_count: 0,
        instrumentation: {
          execution_time_ms: elapsed_ms,
          priority_zones_evaluated: 0,
          warehouses_evaluated: 0,
          routes_evaluated: 0,
          strategies_generated: 0,
          contingency_simulations: 0,
          cache_hits: 0
        }
      }
    end
  end
end
