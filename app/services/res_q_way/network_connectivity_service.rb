# frozen_string_literal: true

module ResQWay
  class NetworkConnectivityService
    EARTH_RADIUS_KM = 6371.0

    class Edge
      attr_reader :road_id, :road_number, :name, :origin_id, :destination_id,
                  :distance, :status, :risk_score, :disruption_probability,
                  :road_condition, :travel_cost, :coordinates, :road

      def initialize(road_id:, road_number:, name:, origin_id:, destination_id:,
                     distance:, status:, risk_score:, disruption_probability:,
                     road_condition: "good", travel_cost:, coordinates: [], road: nil)
        @road_id = road_id
        @road_number = road_number
        @name = name
        @origin_id = origin_id
        @destination_id = destination_id
        @distance = distance.to_f
        @status = status.to_s.downcase
        @risk_score = risk_score.to_f
        @disruption_probability = disruption_probability.to_f
        @road_condition = road_condition.to_s.downcase
        @travel_cost = travel_cost.to_f
        @coordinates = coordinates || []
        @road = road
      end

      def blocked?
        status == "blocked" || travel_cost == Float::INFINITY
      end

      def passable?
        !blocked?
      end

      def as_json
        {
          road_id: road_id,
          road_number: road_number,
          name: name,
          origin_id: origin_id,
          destination_id: destination_id,
          distance: distance,
          status: status,
          risk_score: risk_score,
          disruption_probability: disruption_probability,
          road_condition: road_condition,
          travel_cost: travel_cost.infinite? ? 999999.0 : travel_cost.round(1),
          coordinates: coordinates
        }
      end
    end

    class Node
      attr_reader :id, :name, :state, :district, :location_type, :population,
                  :latitude, :longitude, :warehouses, :location

      def initialize(location:, warehouses: [])
        @location = location
        @id = location.id
        @name = location.name
        @state = location.state
        @district = location.district
        @location_type = location.location_type
        @population = location.population.to_i
        @latitude = location.latitude.to_f
        @longitude = location.longitude.to_f
        @warehouses = warehouses || []
      end

      def warehouse?
        @warehouses.any?
      end

      def operational_warehouse?
        @warehouses.any? { |w| w.operational_status == "OPERATIONAL" }
      end

      def as_json
        {
          id: id,
          name: name,
          state: state,
          district: district,
          location_type: location_type,
          population: population,
          latitude: latitude,
          longitude: longitude,
          is_warehouse: warehouse?,
          warehouses: warehouses.map(&:name),
          coordinates: [latitude, longitude]
        }
      end
    end

    attr_reader :locations, :roads, :warehouses, :nodes, :edges,
                :blocked_road_ids, :simulated_closed_road_ids, :simulated_road_statuses

    def initialize(locations: nil, roads: nil, warehouses: nil, blocked_road_ids: nil)
      @locations = locations || (defined?(Location) ? Location.all.to_a : [])
      @roads = roads || (defined?(Road) ? Road.all.to_a : [])
      @warehouses = warehouses || (defined?(Warehouse) ? Warehouse.all.to_a : [])
      @blocked_road_ids = Set.new((blocked_road_ids || []).map(&:to_i))
      @simulated_closed_road_ids = Set.new
      @simulated_road_statuses = {}

      build_graph!
    end

    # =========================================================================
    # 1. GRAPH CONSTRUCTION
    # =========================================================================
    def build_graph!
      @nodes = {}
      return if @locations.empty?

      warehouses_by_loc = @warehouses.group_by(&:location_id)

      @locations.each do |loc|
        whs = warehouses_by_loc[loc.id] || []
        if whs.empty?
          whs = @warehouses.select do |w|
            (w.name.to_s.downcase.include?(loc.name.to_s.downcase)) ||
              (w.latitude.present? && loc.latitude.present? &&
               haversine_distance(w.latitude, w.longitude, loc.latitude, loc.longitude) <= 15.0)
          end
        end
        @nodes[loc.id] = Node.new(location: loc, warehouses: whs)
      end

      @edges = []
      @roads.each do |road|
        edge = build_edge_for(road)
        @edges << edge if edge
      end
    end

    # =========================================================================
    # 2. FULL NETWORK ANALYSIS
    # =========================================================================
    def analyze(simulated_road_ids: [], simulated_statuses: {}, include_criticalities: true)
      @simulated_closed_road_ids = Set.new(simulated_road_ids.map(&:to_i))
      @simulated_road_statuses = simulated_statuses || {}

      # Handle empty network edge case
      if @nodes.empty?
        return {
          network_health_score: 100.0,
          isolation_impact_score: 0.0,
          network_health_trend: "STABLE",
          total_settlements: 0,
          connected_settlements_count: 0,
          isolated_settlements_count: 0,
          isolated_population: 0,
          connected_components_count: 0,
          largest_component_size: 0,
          disconnected_clusters: [],
          components: [],
          isolated_settlements: [],
          reachable_settlements: [],
          all_settlements: [],
          critical_roads: [],
          warehouses_status: [],
          simulated_closed_road_ids: [],
          blocked_roads_count: 0,
          critical_corridors_at_risk_count: 0,
          explanation: "Empty transport network: zero settlement nodes registered.",
          analyzed_at: Time.current
        }
      end

      # Baseline graph: physical network with zero closures
      baseline_components = compute_components(passable_edges: all_physical_edges)
      baseline_isolated = detect_isolated_nodes(baseline_components)

      # Active operational graph: excludes currently blocked & simulated closed edges
      active_passable_edges = current_passable_edges
      active_components = compute_components(passable_edges: active_passable_edges)
      active_isolated = detect_isolated_nodes(active_components)

      # Calculate Impact and Health
      impact_score = calculate_isolation_impact_score(
        baseline_isolated: baseline_isolated,
        active_isolated: active_isolated,
        total_nodes: @nodes.size,
        components_count: active_components.size
      )
      health_score = [100.0 - impact_score, 0.0].max.round(1)

      # Identify Bridges and Critical Corridors
      critical_roads = if include_criticalities
                         evaluate_road_criticalities
                       else
                         []
                       end

      # Reset simulated closed road ids after criticality evaluation to prevent state pollution
      @simulated_closed_road_ids = Set.new(simulated_road_ids.map(&:to_i))
      @simulated_road_statuses = simulated_statuses || {}

      # Identify Alternative Warehouses for Isolated or Affected Settlements
      settlement_analyses = build_settlement_analyses(active_components, active_isolated)

      # Active Warehouses connectivity status
      warehouse_statuses = evaluate_warehouse_connectivity(active_components)

      # Largest component & disconnected clusters
      largest_size = active_components.map(&:size).max || 0
      disconnected_clusters = active_components.select do |comp|
        comp.size > 1 && !comp.any? { |nid| @nodes[nid]&.operational_warehouse? }
      end

      blocked_count = @edges.count { |e| edge_blocked?(e) }
      crit_at_risk_count = critical_roads.count { |r| r[:criticality_score] >= 65.0 && r[:status] != "blocked" }

      trend = determine_health_trend(health_score, blocked_count, crit_at_risk_count)
      explanation = build_network_health_explanation(health_score, trend, active_isolated, critical_roads, blocked_count)

      {
        network_health_score: health_score,
        isolation_impact_score: impact_score,
        network_health_trend: trend,
        total_settlements: @nodes.size,
        connected_settlements_count: @nodes.size - active_isolated.size,
        isolated_settlements_count: active_isolated.size,
        isolated_population: active_isolated.sum { |id| @nodes[id]&.population || 0 },
        connected_components_count: active_components.size,
        largest_component_size: largest_size,
        disconnected_clusters: format_components(disconnected_clusters),
        components: format_components(active_components),
        isolated_settlements: settlement_analyses.select { |s| s[:isolated] },
        reachable_settlements: settlement_analyses.reject { |s| s[:isolated] },
        all_settlements: settlement_analyses,
        critical_roads: critical_roads,
        warehouses_status: warehouse_statuses,
        simulated_closed_road_ids: @simulated_closed_road_ids.to_a,
        blocked_roads_count: blocked_count,
        confirmed_blocked_roads_count: @edges.count { |e| edge_blocked?(e) && edge_blockage_classification(e)[:confirmed] },
        possible_blocked_roads_count: @edges.count { |e| edge_blocked?(e) && !edge_blockage_classification(e)[:confirmed] },
        critical_corridors_at_risk_count: crit_at_risk_count,
        explanation: explanation,
        analyzed_at: Time.current
      }
    end

    # =========================================================================
    # 3. CONNECTED COMPONENTS (BFS)
    # =========================================================================
    def compute_components(passable_edges:)
      adj = Hash.new { |h, k| h[k] = [] }
      passable_edges.each do |edge|
        adj[edge.origin_id] << edge.destination_id
        adj[edge.destination_id] << edge.origin_id
      end

      visited = Set.new
      components = []

      @nodes.keys.each do |node_id|
        next if visited.include?(node_id)

        component = []
        queue = [node_id]
        visited.add(node_id)

        until queue.empty?
          curr = queue.shift
          component << curr

          adj[curr].each do |neighbor|
            unless visited.include?(neighbor)
              visited.add(neighbor)
              queue.push(neighbor)
            end
          end
        end

        components << component
      end

      components.sort_by { |c| -c.size }
    end

    # =========================================================================
    # 4. ISOLATED SETTLEMENTS DETECTION
    # =========================================================================
    def detect_isolated_nodes(components)
      isolated = Set.new

      components.each do |comp|
        # A component is serviced if it has an operational warehouse
        has_warehouse = comp.any? { |nid| @nodes[nid]&.operational_warehouse? }

        unless has_warehouse
          comp.each { |nid| isolated.add(nid) }
        end
      end

      isolated
    end

    # =========================================================================
    # 5. SIMULATE ROAD CLOSURE (What-If Disruption Sandbox)
    # =========================================================================
    def simulate_road_closure(road_id_or_ids, status: "blocked")
      ids = Array(road_id_or_ids).map(&:to_i)
      target_roads = @roads.select { |r| ids.include?(r.id) }
      target_road_names = target_roads.map(&:name).join(", ")

      sim_statuses = ids.to_h { |id| [id, status.to_s.downcase] }

      # Pre-simulation state (memoized per service instance for high performance)
      pre_analysis = baseline_analysis

      # Post-simulation state
      post_analysis = if status.to_s.downcase == "open" || status.to_s.downcase == "accessible"
                        analyze(simulated_road_ids: [], simulated_statuses: sim_statuses, include_criticalities: false)
                      else
                        analyze(simulated_road_ids: ids, simulated_statuses: sim_statuses, include_criticalities: false)
                      end

      newly_isolated_ids = post_analysis[:isolated_settlements].map { |s| s[:id] } -
                           pre_analysis[:isolated_settlements].map { |s| s[:id] }

      newly_isolated_nodes = newly_isolated_ids.map { |nid| @nodes[nid] }.compact
      affected_wh = post_analysis[:warehouses_status].select { |w| !w[:reachable] && w[:operational] }

      diff_impact = (post_analysis[:isolation_impact_score] - pre_analysis[:isolation_impact_score]).round(1)
      criticality = calculate_single_disruption_criticality(target_roads, newly_isolated_nodes, post_analysis)

      action_recommendation = generate_recommendation_for_closure(target_roads, newly_isolated_nodes, affected_wh)

      {
        simulated_roads: target_roads.map { |r| { id: r.id, number: r.road_number, name: r.name, status: status } },
        target_road_names: target_road_names,
        simulation_status: status,
        connectivity_impact: impact_label_for(diff_impact + 20.0),
        pre_connected_settlements: pre_analysis[:connected_settlements_count],
        post_connected_settlements: post_analysis[:connected_settlements_count],
        newly_isolated_settlements: newly_isolated_nodes.map(&:name),
        newly_isolated_count: newly_isolated_nodes.size,
        total_isolated_settlements: post_analysis[:isolated_settlements_count],
        affected_warehouses_count: affected_wh.size,
        affected_warehouses: affected_wh.map { |w| w[:name] },
        criticality_score: criticality,
        isolation_impact_score: post_analysis[:isolation_impact_score],
        network_health_score: post_analysis[:network_health_score],
        network_health_trend: post_analysis[:network_health_trend],
        alternative_access: newly_isolated_nodes.empty? ? "Fully Available via Alternate Corridors" : (post_analysis[:connected_settlements_count] > 0 ? "Limited / Aerial Only" : "Zero Access"),
        recommended_action: action_recommendation,
        narrative_summary: build_simulation_narrative(target_roads, newly_isolated_nodes, criticality, status)
      }
    end

    def baseline_analysis
      @cached_baseline_analysis ||= analyze(simulated_road_ids: [], simulated_statuses: {}, include_criticalities: false)
    end

    def alternative_route_analysis(road_id)
      road = @roads.find { |r| r.id == road_id }
      return nil unless road

      edge = @edges.find { |e| e.road_id == road.id }
      return nil unless edge

      orig_id = edge.origin_id
      dest_id = edge.destination_id
      orig_dist = edge.distance.to_f

      # Passable physical edges excluding the evaluated road
      other_edges = @edges.reject { |e| e.road_id == road_id || edge_blocked?(e) }

      distances = run_dijkstra(orig_id, other_edges)
      alt_dist = distances[dest_id]

      if alt_dist.nil? || alt_dist == Float::INFINITY
        {
          has_alternative: false,
          alternative_distance_km: nil,
          original_distance_km: orig_dist.round(1),
          detour_penalty_km: nil,
          detour_ratio: nil,
          resilience_score: 0.0,
          resilience_category: "NO_ALTERNATIVE",
          status_label: "Zero overland alternative route"
        }
      else
        detour_km = [alt_dist - orig_dist, 0.0].max.round(1)
        detour_pct = orig_dist.positive? ? ((detour_km / orig_dist) * 100.0).round(1) : 0.0

        score = if detour_pct <= 15.0
                  (100.0 - (detour_pct * 0.67)).clamp(90.0, 100.0)
                elsif detour_pct <= 50.0
                  (89.0 - ((detour_pct - 15.0) * 0.54)).clamp(70.0, 89.0)
                elsif detour_pct <= 150.0
                  (69.0 - ((detour_pct - 50.0) * 0.29)).clamp(40.0, 69.0)
                else
                  [39.0 - ((detour_pct - 150.0) * 0.1), 1.0].max.clamp(1.0, 39.0)
                end

        cat = if score >= 90.0
                "MULTIPLE_SAFE_ALTERNATIVES"
              elsif score >= 70.0
                "MINOR_DETOUR"
              elsif score >= 40.0
                "LONG_OR_RISKY_DETOUR"
              else
                "SEVERELY_CONSTRAINED"
              end

        {
          has_alternative: true,
          alternative_distance_km: alt_dist.round(1),
          original_distance_km: orig_dist.round(1),
          detour_penalty_km: detour_km,
          detour_ratio: detour_pct,
          resilience_score: score.round(1),
          resilience_category: cat,
          status_label: "#{cat.titleize} (+#{detour_km} km / +#{detour_pct}%)"
        }
      end
    end

    def simulate_road_status(road_id, status:)
      simulate_road_closure(road_id, status: status)
    end

    def simulate_multiple_road_closures(road_ids, status: "blocked")
      clean_ids = Array(road_ids).compact.map(&:to_i).uniq.reject(&:zero?)
      simulate_road_closure(clean_ids, status: status)
    end


    # =========================================================================
    # 6. ISOLATION IMPACT SCORE (0 - 100)
    # =========================================================================
    def calculate_isolation_impact_score(baseline_isolated:, active_isolated:, total_nodes:, components_count:)
      return 0.0 if total_nodes.zero?

      new_isolated_count = [active_isolated.size - baseline_isolated.size, 0].max
      isolated_ratio = active_isolated.size.to_f / total_nodes.to_f

      total_pop = @nodes.values.sum(&:population)
      isolated_pop = active_isolated.sum { |id| @nodes[id]&.population || 0 }
      pop_ratio = total_pop.positive? ? (isolated_pop.to_f / total_pop.to_f) : 0.0

      total_wh = @warehouses.count { |w| w.operational_status == "OPERATIONAL" }
      cut_off_wh = @warehouses.count do |w|
        loc_id = w.location_id
        loc_id && active_isolated.include?(loc_id)
      end
      wh_ratio = total_wh.positive? ? (cut_off_wh.to_f / total_wh.to_f) : 0.0

      frag_ratio = [(components_count - 1).to_f / [total_nodes, 1].max.to_f, 1.0].min

      weighted = (isolated_ratio * 35.0) +
                 (pop_ratio * 35.0) +
                 (wh_ratio * 20.0) +
                 (frag_ratio * 10.0)

      if new_isolated_count.positive?
        weighted += (new_isolated_count * 5.0)
      end

      weighted.clamp(0.0, 100.0).round(1)
    end

    # =========================================================================
    # 7. CRITICAL ROAD IDENTIFICATION & BRIDGE DETECTION
    # =========================================================================
    def evaluate_road_criticalities
      bridges = detect_bridges(all_physical_edges)

      base_analysis = analyze(simulated_road_ids: [], include_criticalities: false)
      base_connected = base_analysis[:connected_settlements_count]

      criticalities = []

      @roads.each do |road|
        edge = @edges.find { |e| e.road_id == road.id }
        next unless edge

        is_bridge = bridges.include?(edge.road_id)

        # Simulate failure of this road
        sim_post = analyze(simulated_road_ids: [road.id], include_criticalities: false)
        lost_settlements = [base_connected - sim_post[:connected_settlements_count], 0].max

        c_score = 0.0
        c_score += 40.0 if is_bridge
        c_score += [lost_settlements * 12.0, 35.0].min
        c_score += [road.risk_score * 0.15, 15.0].min
        c_score += 10.0 if road.status == "blocked"

        c_score = c_score.clamp(5.0, 100.0).round(1)

        level = if c_score >= 75.0
                  "critical"
                elsif c_score >= 50.0
                  "high"
                elsif c_score >= 25.0
                  "moderate"
                else
                  "low"
                end

        explanation = if is_bridge && lost_settlements.positive?
                        "Single point of failure (Tarjan Bridge). Failure disconnects #{lost_settlements} settlement(s) with zero alternate overland roads."
                      elsif is_bridge
                        "Topological bridge across distinct regional clusters. Removal partitions sub-networks."
                      elsif lost_settlements.positive?
                        "Reduces reachable network habitations by #{lost_settlements} settlement(s)."
                      else
                        "Redundant bypass corridor available; failure does not sever primary habitations."
                      end

        criticalities << {
          road_id: road.id,
          road_number: road.road_number,
          name: road.name,
          state: road.state,
          status: road.status,
          risk_score: road.risk_score,
          criticality_score: c_score,
          criticality_level: level,
          is_bridge: is_bridge,
          lost_settlements_on_failure: lost_settlements,
          explanation: explanation
        }
      end

      criticalities.sort_by { |r| -r[:criticality_score] }
    end

    # =========================================================================
    # 8. TARJAN'S BRIDGE FINDING ALGORITHM
    # =========================================================================
    def detect_bridges(edge_list)
      adj = Hash.new { |h, k| h[k] = [] }
      edge_list.each do |e|
        adj[e.origin_id] << { neighbor: e.destination_id, edge_id: e.road_id }
        adj[e.destination_id] << { neighbor: e.origin_id, edge_id: e.road_id }
      end

      discovery_time = {}
      low_link = {}
      bridges = Set.new
      timer = 0

      dfs = lambda do |u, parent_edge|
        timer += 1
        discovery_time[u] = low_link[u] = timer

        adj[u].each do |item|
          v = item[:neighbor]
          edge_id = item[:edge_id]

          next if edge_id == parent_edge

          if discovery_time.key?(v)
            low_link[u] = [low_link[u], discovery_time[v]].min
          else
            dfs.call(v, edge_id)
            low_link[u] = [low_link[u], low_link[v]].min

            if low_link[v] > discovery_time[u]
              bridges.add(edge_id)
            end
          end
        end
      end

      @nodes.keys.each do |node_id|
        dfs.call(node_id, nil) unless discovery_time.key?(node_id)
      end

      bridges
    end

    # =========================================================================
    # 9. ALTERNATIVE REACHABLE LOGISTICS HUBS (DIJKSTRA)
    # =========================================================================
    def find_nearest_reachable_warehouse(from_node_id, current_component)
      return nil unless current_component.include?(from_node_id)

      candidate_warehouses = @warehouses.select do |w|
        next false unless w.operational_status == "OPERATIONAL"
        wh_node_id = w.location_id || @nodes.values.find { |n| n.warehouses.include?(w) }&.id
        wh_node_id && current_component.include?(wh_node_id)
      end

      return nil if candidate_warehouses.empty?

      distances = run_dijkstra(from_node_id, current_passable_edges)

      best_wh = nil
      min_dist = Float::INFINITY

      candidate_warehouses.each do |wh|
        wh_node_id = wh.location_id || @nodes.values.find { |n| n.warehouses.include?(wh) }&.id
        dist = distances[wh_node_id] || Float::INFINITY
        if dist < min_dist
          min_dist = dist
          best_wh = wh
        end
      end

      if best_wh && min_dist < Float::INFINITY
        {
          warehouse_id: best_wh.id,
          warehouse_name: best_wh.name,
          distance_km: min_dist.round(1),
          readiness_score: best_wh.readiness_score,
          status: "Reachable overland"
        }
      else
        nil
      end
    end

    def run_dijkstra(start_node_id, edge_list)
      adj = Hash.new { |h, k| h[k] = [] }
      edge_list.each do |e|
        d = e.distance.to_f
        adj[e.origin_id] << { to: e.destination_id, weight: d }
        adj[e.destination_id] << { to: e.origin_id, weight: d }
      end

      distances = Hash.new(Float::INFINITY)
      distances[start_node_id] = 0.0

      visited = Set.new
      queue = [[0.0, start_node_id]]

      until queue.empty?
        queue.sort_by!(&:first)
        curr_dist, u = queue.shift

        next if visited.include?(u)
        visited.add(u)

        adj[u].each do |item|
          v = item[:to]
          w = item[:weight]
          new_dist = curr_dist + w

          if new_dist < distances[v]
            distances[v] = new_dist
            queue.push([new_dist, v])
          end
        end
      end

      distances
    end

    # =========================================================================
    # 10. ALERT INTEGRATION
    # =========================================================================
    def generate_connectivity_alerts!
      return [] unless defined?(LogisticsAlert)

      analysis = analyze
      generated_alerts = []

      # 1. Alert for Isolated Settlements
      analysis[:isolated_settlements].each do |s|
        dedup_key = "iso_settlement_#{s[:id]}_#{Date.today.strftime('%Y%m%d')}"
        next if LogisticsAlert.where(dedup_key: dedup_key).exists?

        alert = LogisticsAlert.create!(
          alert_type: "settlement_isolated",
          severity: "critical",
          title: "🚨 Isolated Habitation: #{s[:name]} (#{s[:state]})",
          message: s[:explanation],
          location_name: s[:name],
          latitude: s[:latitude],
          longitude: s[:longitude],
          recommended_action: s[:recommended_action],
          dedup_key: dedup_key,
          metadata_json: {
            settlement_id: s[:id],
            population: s[:population],
            alternative_warehouse: s[:alternative_warehouse]
          }
        )
        generated_alerts << alert
      end

      # 2. Alert for Isolated Warehouses
      analysis[:warehouses_status].select { |w| !w[:reachable] && w[:operational] }.each do |w|
        dedup_key = "iso_warehouse_#{w[:id]}_#{Date.today.strftime('%Y%m%d')}"
        next if LogisticsAlert.where(dedup_key: dedup_key).exists?

        alert = LogisticsAlert.create!(
          alert_type: "warehouse_isolated",
          severity: "critical",
          title: "🏭 Relief Depot Isolated: #{w[:name]}",
          message: "Operational warehouse #{w[:name]} has lost road continuity to external supply networks and habitations.",
          location_name: w[:name],
          recommended_action: "Establish emergency helicopter staging link or reopen nearest arterial corridor.",
          dedup_key: dedup_key,
          metadata_json: {
            warehouse_id: w[:id],
            operational: w[:operational]
          }
        )
        generated_alerts << alert
      end

      # 3. Alert for Blocked Critical Corridors
      analysis[:critical_roads].select { |r| r[:status] == "blocked" && r[:criticality_score] >= 65.0 }.each do |r|
        dedup_key = "crit_blocked_#{r[:road_id]}_#{Date.today.strftime('%Y%m%d')}"
        next if LogisticsAlert.where(dedup_key: dedup_key).exists?

        alert = LogisticsAlert.create!(
          alert_type: "critical_corridor_blocked",
          severity: "critical",
          title: "⛔ Severed Strategic Lifeline: #{r[:road_number]} • #{r[:name]}",
          message: "Critical corridor with score #{r[:criticality_score]}/100 is completely impassable. #{r[:explanation]}",
          location_name: r[:name],
          recommended_action: "Reroute relief transport via alternative corridors or initiate emergency corridor clearance.",
          dedup_key: dedup_key,
          metadata_json: {
            road_id: r[:road_id],
            criticality_score: r[:criticality_score],
            is_bridge: r[:is_bridge],
            lost_settlements: r[:lost_settlements_on_failure]
          }
        )
        generated_alerts << alert
      end

      # 3. Alert for Network Health Drop
      if analysis[:network_health_score] < 60.0
        dedup_key = "health_drop_#{Date.today.strftime('%Y%m%d')}"
        unless LogisticsAlert.where(dedup_key: dedup_key).exists?
          alert = LogisticsAlert.create!(
            alert_type: "network_connectivity_drop",
            severity: "high",
            title: "📉 Regional Network Resilience Degradation (Score: #{analysis[:network_health_score]}/100)",
            message: analysis[:explanation],
            location_name: "North Eastern Region",
            recommended_action: "Convene emergency inter-agency disaster logistics dispatch review.",
            dedup_key: dedup_key,
            metadata_json: {
              network_health_score: analysis[:network_health_score],
              isolated_settlements_count: analysis[:isolated_settlements_count],
              trend: analysis[:network_health_trend]
            }
          )
          generated_alerts << alert
        end
      end

      generated_alerts
    end

    def classify_blockage_confidence(incident_or_score)
      score = if incident_or_score.is_a?(Numeric)
                incident_or_score.to_f
              elsif incident_or_score.respond_to?(:confidence_score)
                incident_or_score.confidence_score.to_f
              elsif incident_or_score.respond_to?(:ai_confidence_score)
                (incident_or_score.ai_confidence_score || 70.0).to_f
              else
                70.0
              end

      if score >= 75.0
        {
          status: "CONFIRMED_BLOCKAGE",
          confirmed: true,
          confidence_score: score,
          recommendation: "Immediate graph disconnection. Reroute logistics convoys and evaluate isolated settlements."
        }
      else
        {
          status: "POSSIBLE_BLOCKAGE",
          confirmed: false,
          confidence_score: score,
          recommendation: "Dispatch ground patrol or UAV to verify blockage before full regional graph isolation."
        }
      end
    end

    def edge_blockage_classification(edge)
      road = edge.road
      return { status: "OPEN", confirmed: false, confidence_score: 100.0 } unless edge_blocked?(edge)

      # Check if road has associated recent incidents
      if defined?(Incident) && road.present?
        recent_incidents = Incident.where(
          status: %w[reported verified]
        ).where(
          "reported_at >= ?", 72.hours.ago
        ).select do |inc|
          (inc.state == road.state) &&
            ((inc.latitude - road.latitude).abs <= 0.1 && (inc.longitude - road.longitude).abs <= 0.1 rescue false)
        end

        if recent_incidents.any?
          max_conf = recent_incidents.map { |i| (i.ai_confidence_score || 70.0).to_f }.max
          return classify_blockage_confidence(max_conf)
        end
      end

      # Default to confirmed if road model explicitly marked blocked
      {
        status: "CONFIRMED_BLOCKAGE",
        confirmed: true,
        confidence_score: 85.0,
        recommendation: "Road status confirmed in registry. Graph rerouted."
      }
    end

    private

    def build_edge_for(road)
      orig_loc, dest_loc = resolve_endpoints_for(road)
      return nil unless orig_loc && dest_loc && orig_loc.id != dest_loc.id

      dist = road.length_km.to_f
      dist = haversine_distance(orig_loc.latitude, orig_loc.longitude, dest_loc.latitude, dest_loc.longitude) if dist <= 0

      risk = road.risk_score.to_f
      prob = road.ml_disruption_probability || (risk / 100.0)

      cost = if road.status == "blocked"
               Float::INFINITY
             else
               (dist * (1.0 + (risk / 100.0) * 1.5)).round(2)
             end

      Edge.new(
        road_id: road.id,
        road_number: road.road_number,
        name: road.name,
        origin_id: orig_loc.id,
        destination_id: dest_loc.id,
        distance: dist,
        status: road.status,
        risk_score: risk,
        disruption_probability: prob,
        road_condition: road.road_condition,
        travel_cost: cost,
        coordinates: road.coordinates,
        road: road
      )
    end

    def resolve_endpoints_for(road)
      if road.respond_to?(:origin_location_id) && road.origin_location_id.present? &&
         road.respond_to?(:destination_location_id) && road.destination_location_id.present?
        orig = @nodes[road.origin_location_id]&.location
        dest = @nodes[road.destination_location_id]&.location
        return [orig, dest] if orig && dest
      end

      coords = road.coordinates
      if coords.size >= 2
        first_pt = coords.first
        last_pt = coords.last

        orig = find_nearest_location_to(first_pt[0], first_pt[1])
        dest = find_nearest_location_to(last_pt[0], last_pt[1])

        if orig && dest && orig.id != dest.id
          return [orig, dest]
        end
      end

      matched_locs = @locations.select do |loc|
        road.name.to_s.downcase.include?(loc.name.to_s.downcase)
      end

      if matched_locs.size >= 2
        return [matched_locs.first, matched_locs.second]
      end

      mid_pt = coords.size.positive? ? coords[coords.size / 2] : nil
      if mid_pt
        sorted = @locations.sort_by do |loc|
          haversine_distance(mid_pt[0], mid_pt[1], loc.latitude, loc.longitude)
        end
        [sorted[0], sorted[1]]
      else
        nil
      end
    end

    def find_nearest_location_to(lat, lon)
      return nil if lat.nil? || lon.nil?

      @locations.min_by do |loc|
        haversine_distance(lat, lon, loc.latitude, loc.longitude)
      end
    end

    def haversine_distance(lat1, lon1, lat2, lon2)
      return 0.0 if lat1.nil? || lon1.nil? || lat2.nil? || lon2.nil?

      dlat = (lat2 - lat1) * Math::PI / 180.0
      dlon = (lon2 - lon1) * Math::PI / 180.0

      a = Math.sin(dlat / 2)**2 +
          Math.cos(lat1 * Math::PI / 180.0) * Math.cos(lat2 * Math::PI / 180.0) *
          Math.sin(dlon / 2)**2

      c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
      (EARTH_RADIUS_KM * c).round(2)
    end

    def build_settlement_analyses(components, isolated_set)
      @nodes.values.map do |node|
        comp = components.find { |c| c.include?(node.id) } || [node.id]
        is_iso = isolated_set.include?(node.id)

        incident_edges = @edges.select { |e| e.origin_id == node.id || e.destination_id == node.id }
        blocked_inc = incident_edges.select { |e| edge_blocked?(e) }

        alt_wh = find_nearest_reachable_warehouse(node.id, comp)

        cause = if is_iso
                  if incident_edges.empty?
                    "No registered road corridor connections in GIS database."
                  elsif blocked_inc.size == incident_edges.size
                    corridor_names = blocked_inc.map(&:road_number).join(", ")
                    "Primary connecting corridor(s) #{corridor_names} blocked or impassable."
                  else
                    "Reachable road sub-network contains no operational relief warehouse or depot."
                  end
                else
                  "Reachable through operational road corridors and serviced by regional logistics depots."
                end

        alt_access = if is_iso
                       if alt_wh
                         "Overland bypass via #{alt_wh[:warehouse_name]} (#{alt_wh[:distance_km]} km)"
                       else
                         "None currently available (overland isolated; emergency aerial drop required)"
                       end
                     else
                       alt_wh ? "Direct overland access to #{alt_wh[:warehouse_name]} (#{alt_wh[:distance_km]} km)" : "Normal road connectivity"
                     end

        rec_action = if is_iso
                       if alt_wh
                         "Dispatch overland convoy from #{alt_wh[:warehouse_name]} (#{alt_wh[:distance_km]} km)."
                       else
                         "Zero reachable depots overland. Initiate emergency aerial supply drop or drone logistics corridor."
                       end
                     else
                       "Maintain standard scheduled supply replenishments."
                     end

        {
          id: node.id,
          settlement: node.name,
          name: node.name,
          state: node.state,
          district: node.district,
          population: node.population,
          latitude: node.latitude,
          longitude: node.longitude,
          is_warehouse: node.warehouse?,
          status: is_iso ? "ISOLATED" : "CONNECTED",
          isolated: is_iso,
          cause: cause,
          previously_connected_routes: incident_edges.map(&:name),
          alternative_access: alt_access,
          component_size: comp.size,
          explanation: cause,
          alternative_warehouse: alt_wh,
          recommended_action: rec_action
        }
      end
    end

    def evaluate_warehouse_connectivity(components)
      @warehouses.map do |wh|
        loc_id = wh.location_id
        node = loc_id ? @nodes[loc_id] : @nodes.values.find { |n| n.warehouses.include?(wh) }
        node_id = node&.id

        is_connected = false
        comp_size = 0

        if node_id
          comp = components.find { |c| c.include?(node_id) }
          if comp
            is_connected = comp.size > 1
            comp_size = comp.size
          end
        end

        {
          id: wh.id,
          name: wh.name,
          operational: wh.operational_status == "OPERATIONAL",
          reachable: is_connected,
          component_size: comp_size
        }
      end
    end

    def edge_blocked?(edge)
      # Check simulated statuses first
      sim_status = @simulated_road_statuses[edge.road_id]
      return false if sim_status == "open" || sim_status == "accessible"
      return true if sim_status == "blocked"

      # Check simulated closures
      return true if @simulated_closed_road_ids.include?(edge.road_id)

      # Check database / model status
      return true if @blocked_road_ids.include?(edge.road_id)
      return true if edge.status == "blocked"

      false
    end

    def all_physical_edges
      @edges
    end

    def current_passable_edges
      @edges.reject { |e| edge_blocked?(e) }
    end

    def format_components(comps)
      comps.map.with_index do |comp, idx|
        {
          cluster_id: idx + 1,
          size: comp.size,
          node_ids: comp,
          node_names: comp.map { |id| @nodes[id]&.name }.compact,
          has_warehouse: comp.any? { |id| @nodes[id]&.operational_warehouse? }
        }
      end
    end

    def calculate_single_disruption_criticality(target_roads, newly_isolated_nodes, post_analysis)
      score = 0.0
      return 0.0 if target_roads.empty?

      # Factor 1: Isolated settlements
      score += [newly_isolated_nodes.size * 20.0, 50.0].min

      # Factor 2: Max road risk
      max_risk = target_roads.map(&:risk_score).max || 0.0
      score += [max_risk * 0.25, 25.0].min

      # Factor 3: High-impact closure
      score += 25.0 if newly_isolated_nodes.size.positive?

      # Factor 4: Bridge impact
      if post_analysis[:connected_components_count] > 1
        score += 15.0
      end

      score.clamp(10.0, 100.0).round(1)
    end

    def generate_recommendation_for_closure(target_roads, newly_isolated, affected_wh)
      names = target_roads.map(&:road_number).join(", ")
      if newly_isolated.any?
        iso_names = newly_isolated.map(&:name).join(", ")
        "CRITICAL: Closure of #{names} causes severe isolation of #{iso_names}. Mobilize emergency NDRF bypass and clear rockfalls."
      elsif affected_wh.any?
        "WARNING: Closure of #{names} severs road access to primary relief depots. Reroute supply convoys via secondary state highways."
      else
        "ADVISORY: Closure of #{names} increases route circuity. Activate regional alternate freight corridors."
      end
    end

    def build_simulation_narrative(target_roads, newly_isolated, criticality, status = "blocked")
      names = target_roads.map { |r| "#{r.road_number} (#{r.name})" }.join(", ")
      if status == "open" || status == "accessible"
        "Simulated reopening of #{names} restores network connectivity and relieves freight congestion."
      elsif newly_isolated.any?
        iso_names = newly_isolated.map(&:name).join(", ")
        "Simulated closure of #{names} creates a severe network partition (Criticality #{criticality}/100), completely isolating #{newly_isolated.size} settlement(s): #{iso_names}."
      else
        "Simulated closure of #{names} reduces network redundancy (Criticality #{criticality}/100), but secondary corridors remain passable."
      end
    end

    def determine_health_trend(score, blocked_count, crit_at_risk_count)
      if score < 50.0 || blocked_count >= 3
        "CRITICAL"
      elsif score < 75.0 || blocked_count.positive? || crit_at_risk_count >= 3
        "DECLINING"
      elsif score >= 90.0 && blocked_count.zero?
        "STABLE"
      else
        "IMPROVING"
      end
    end

    def build_network_health_explanation(health_score, trend, isolated_set, critical_roads, blocked_count)
      if isolated_set.empty? && blocked_count.zero?
        "Regional network operating at full operational capacity (Health #{health_score}/100). All settlements connected to active supply routes."
      else
        crit_blocked = critical_roads.select { |r| r[:status] == "blocked" }.map { |r| r[:road_number] }.join(", ")
        cause_part = crit_blocked.present? ? "due to blockage of key corridor(s) #{crit_blocked}" : "due to localized road closures"
        "Regional network health is #{health_score}/100 (Trend: #{trend}) with #{isolated_set.size} isolated settlement(s) #{cause_part}."
      end
    end

    def impact_label_for(score)
      if score >= 75.0
        "Severe Disruption"
      elsif score >= 50.0
        "Moderate Disruption"
      elsif score >= 25.0
        "Minor Disruption"
      else
        "Negligible Impact"
      end
    end
  end
end
