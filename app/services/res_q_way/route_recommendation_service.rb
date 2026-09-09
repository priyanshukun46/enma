module ResQWay
  class RouteRecommendationService
    EARTH_RADIUS_KM = 6371.0
    PROFILES_PATH = Rails.root.join("config", "res_q_way_route_profiles.yml")

    attr_reader :origin, :destination, :priority_mode, :vehicle_type, :cargo_type, :options

    def initialize(origin:, destination:, priority_mode: "balanced", vehicle_type: "Truck", cargo_type: "General Supplies", options: {})
      @origin = origin
      @destination = destination
      @priority_mode = priority_mode.to_s.downcase.presence || "balanced"
      @vehicle_type = vehicle_type.to_s.presence || "Truck"
      @cargo_type = cargo_type.to_s.presence || "General Supplies"
      @options = options
    end

    def self.recommend(origin:, destination:, priority_mode: "balanced", vehicle_type: "Truck", cargo_type: "General Supplies")
      new(
        origin: origin,
        destination: destination,
        priority_mode: priority_mode,
        vehicle_type: vehicle_type,
        cargo_type: cargo_type
      ).recommend
    end

    def recommend
      validate_inputs!

      # 1. Fetch raw route alternatives from Routing Provider
      raw_routes = Routing::RoutingProvider.calculate_routes(origin, destination, options)
      raw_routes = ensure_minimum_alternatives(raw_routes)

      # 2. Gather corridor environmental intelligence
      active_incidents = find_corridor_incidents
      active_emergencies = find_corridor_emergencies

      # 3. Analyze segments and score each candidate route
      analyzed_routes = raw_routes.map.with_index do |route_candidate, idx|
        analyze_route_candidate(route_candidate, idx, active_incidents, active_emergencies)
      end

      # 4. Rank candidate routes using normalized optimization score
      ranked_routes = rank_routes(analyzed_routes)

      # 5. Select recommended route and build explainable reasoning
      best_route = select_champion_route(ranked_routes)
      explanation = build_explainable_recommendation(best_route, ranked_routes)

      # 6. Format result payload
      {
        origin: origin,
        destination: destination,
        priority_mode: priority_mode,
        priority_profile: profile_config,
        vehicle_type: vehicle_type,
        cargo_type: cargo_type,
        recommended_route: best_route,
        routes: ranked_routes,
        explanation: explanation,
        incidents_detected_count: active_incidents.size,
        analyzed_at: Time.current
      }
    end

    # Check if a newly reported incident affects any road segments in a route
    def self.check_rerouting_needed(route_analysis, new_incident)
      return false unless route_analysis && new_incident

      segments = route_analysis.segment_analysis
      inc_lat = new_incident.latitude.to_f
      inc_lon = new_incident.longitude.to_f

      segments.any? do |seg|
        coords = seg[:coordinates] || []
        coords.any? do |pt|
          d = calculate_haversine(pt[0], pt[1], inc_lat, inc_lon)
          d <= 15.0 # within 15 km of route waypoint
        end
      end
    end

    private

    def validate_inputs!
      raise ArgumentError, "Origin location is required" if origin.nil?
      raise ArgumentError, "Destination location is required" if destination.nil?
      orig_id = origin.respond_to?(:id) ? origin.id : nil
      dest_id = destination.respond_to?(:id) ? destination.id : nil
      if orig_id && dest_id && orig_id == dest_id
        raise ArgumentError, "Origin and Destination cannot be the same location"
      end
    end

    def profile_config
      @profile_config ||= begin
        if File.exist?(PROFILES_PATH)
          all_profiles = YAML.load_file(PROFILES_PATH)
          all_profiles[priority_mode] || all_profiles["balanced"]
        else
          default_profile
        end
      end
    end

    def default_profile
      {
        "weights" => {
          "travel_time" => 0.25,
          "distance" => 0.10,
          "route_risk" => 0.30,
          "ml_disruption" => 0.25,
          "incident_penalty" => 0.10
        }
      }
    end

    def profile_weights
      profile_config["weights"] || default_profile["weights"]
    end

    # =========================================================================
    # Route Segment Analysis & Road Matching
    # =========================================================================
    def analyze_route_candidate(raw_route, index, incidents, emergencies)
      coords = raw_route[:coordinates] || []
      dist_km = raw_route[:distance_km].to_f
      provider_hrs = raw_route[:estimated_hours].to_f
      provider_mins = raw_route[:duration_minutes] || (provider_hrs * 60).round

      # Match coordinates with ResQWay Road records
      matched_segments = match_road_segments(coords)

      # Extract Segment Statistics
      segment_risks = matched_segments.map { |s| s[:risk_score].to_f }
      avg_road_risk = segment_risks.any? ? (segment_risks.sum / segment_risks.size.to_f).round(1) : 20.0
      max_segment_risk = segment_risks.max || 20.0

      ml_probs = matched_segments.map { |s| s[:ml_disruption_probability].to_f }
      avg_ml_prob = ml_probs.any? ? (ml_probs.sum / ml_probs.size.to_f).round(3) : 0.20

      # Check for Blocked Segments
      blocked_segments = matched_segments.select { |s| s[:status].to_s.downcase == "blocked" || s[:is_blocked] }
      is_blocked = blocked_segments.any?
      blockage_reason = is_blocked ? "Active road blockage on #{blocked_segments.map { |b| b[:road_number] }.join(', ')}" : nil

      # Check for Network Disconnection / Partition
      net_partition = check_network_partition(origin, destination)
      if net_partition[:disconnected]
        is_blocked = true
        blockage_reason ||= net_partition[:reason]
      end

      # Incident intersections
      incident_exposure = evaluate_incident_exposure(coords, incidents)
      incident_count = incident_exposure[:intersected_count]

      # Weather exposure
      weather_exposure = WeatherService.sample_corridor_weather(coords, fallback_location: origin)
      weather_risk = weather_exposure[:weather_exposure_score].to_f

      # Composite Route Risk Score (0 - 100)
      composite_risk = (
        (avg_road_risk * 0.30) +
        (max_segment_risk * 0.25) +
        ((avg_ml_prob * 100.0) * 0.25) +
        (weather_risk * 0.10) +
        ([incident_count * 20.0, 50.0].min * 0.10)
      ).clamp(0.0, 100.0).round(1)

      # ResQWay Adjusted Delay & ETA (in minutes)
      estimated_delay_mins = calculate_delay_minutes(avg_road_risk, avg_ml_prob, weather_risk, incident_count, matched_segments)
      enma_eta_mins = provider_mins + estimated_delay_mins
      enma_eta_hrs = (enma_eta_mins / 60.0).round(2)

      # Segment Breakdown Counts
      segment_breakdown = {
        low_risk: matched_segments.count { |s| s[:risk_level] == "low" },
        moderate_risk: matched_segments.count { |s| s[:risk_level] == "moderate" },
        high_risk: matched_segments.count { |s| s[:risk_level] == "high" },
        critical_risk: matched_segments.count { |s| s[:risk_level] == "critical" || s[:status] == "blocked" },
        total_segments: matched_segments.size
      }

      # Categorical Route Classification
      type_key = case index
                 when 0 then :fastest
                 when 1 then :safest
                 else :balanced
                 end

      {
        id: raw_route[:id] || "route_#{index + 1}",
        index: index,
        type: type_key.to_s,
        title: raw_route[:name].presence || "Corridor #{index + 1}",
        distance_km: dist_km,
        provider_duration_minutes: provider_mins,
        provider_estimated_hours: provider_hrs,
        provider_eta_formatted: format_duration(provider_hrs),
        resqway_adjusted_eta_minutes: enma_eta_mins,
        resqway_adjusted_eta_formatted: format_duration(enma_eta_hrs),
        enma_adjusted_eta_minutes: enma_eta_mins,
        enma_adjusted_eta_formatted: format_duration(enma_eta_hrs),
        delay_minutes: estimated_delay_mins,
        delay_formatted: estimated_delay_mins > 0 ? "+#{estimated_delay_mins} mins delay" : "On schedule",
        delay_reason: build_delay_reason(estimated_delay_mins, weather_risk, avg_ml_prob, incident_count),
        coordinates: coords,
        steps: raw_route[:steps] || [],
        source: raw_route[:source] || "provider",
        fallback_used: raw_route[:fallback_used] || false,
        summary: raw_route[:summary] || "Navigable Highway",
        is_blocked: is_blocked,
        blockage_reason: blockage_reason,
        status: is_blocked ? "UNAVAILABLE" : (composite_risk >= 70.0 ? "HIGH_RISK" : (composite_risk >= 40.0 ? "MODERATE_RISK" : "ACCESSIBLE")),
        route_risk_score: composite_risk,
        route_risk_level: classify_risk(composite_risk),
        ml_disruption_probability: avg_ml_prob,
        ml_disruption_percentage: (avg_ml_prob * 100.0).round(1),
        weather_exposure_score: weather_risk,
        incident_count: incident_count,
        matched_segments: matched_segments,
        segment_breakdown: segment_breakdown,
        optimization_score: 0.0 # populated during ranking
      }
    end

    # Match route coordinates to ResQWay Road segments in database
    def match_road_segments(coords)
      return default_mock_segments if coords.empty? || !defined?(Road)

      matched = []
      all_roads = Road.all.to_a

      coords.each_slice(4) do |sub_pts|
        mid_pt = sub_pts[sub_pts.size / 2]
        closest_road = all_roads.min_by do |r|
          r_coords = r.coordinates || []
          if r_coords.any?
            r_coords.map { |rc| calculate_haversine(mid_pt[0], mid_pt[1], rc[0], rc[1]) }.min
          else
            999.0
          end
        end

        if closest_road && !matched.any? { |m| m[:road_id] == closest_road.id }
          ml_prob = closest_road.ml_disruption_probability.presence || (closest_road.risk_score / 100.0 * 0.85).clamp(0.05, 0.95).round(3)
          matched << {
            road_id: closest_road.id,
            road_number: closest_road.road_number,
            name: closest_road.name,
            state: closest_road.state,
            status: closest_road.status,
            risk_score: closest_road.risk_score.round(1),
            risk_level: closest_road.risk_level,
            ml_disruption_probability: ml_prob,
            weather_risk: closest_road.weather_risk.round(1),
            road_condition: closest_road.road_condition,
            coordinates: closest_road.coordinates
          }
        end
      end

      matched.any? ? matched : default_mock_segments
    end

    def default_mock_segments
      [
        {
          road_id: 1,
          road_number: "NH-27",
          name: "Assam Arterial Highway",
          state: "Assam",
          status: "accessible",
          risk_score: 18.0,
          risk_level: "low",
          ml_disruption_probability: 0.12,
          weather_risk: 25.0,
          road_condition: "good",
          coordinates: []
        },
        {
          road_id: 2,
          road_number: "NH-13",
          name: "Trans-Arunachal Highway",
          state: "Arunachal Pradesh",
          status: "accessible",
          risk_score: 35.0,
          risk_level: "moderate",
          ml_disruption_probability: 0.28,
          weather_risk: 45.0,
          road_condition: "moderate",
          coordinates: []
        }
      ]
    end

    # =========================================================================
    # Optimization Scoring & Normalization
    # =========================================================================
    def rank_routes(analyzed_routes)
      weights = profile_weights

      # Extract maximums for normalization
      max_time = [analyzed_routes.map { |r| r[:enma_adjusted_eta_minutes] }.max, 1.0].max.to_f
      max_dist = [analyzed_routes.map { |r| r[:distance_km] }.max, 1.0].max.to_f

      analyzed_routes.each do |route|
        # 1. Normalize Time (0.0 to 100.0)
        norm_time = (route[:enma_adjusted_eta_minutes] / max_time) * 100.0

        # 2. Normalize Distance (0.0 to 100.0)
        norm_dist = (route[:distance_km] / max_dist) * 100.0

        # 3. Route Risk (already 0.0 to 100.0)
        norm_risk = route[:route_risk_score]

        # 4. ML Disruption Probability (scaled to 0.0 to 100.0)
        norm_ml = route[:ml_disruption_probability] * 100.0

        # 5. Incident Penalty (0.0 to 100.0)
        norm_incidents = [route[:incident_count] * 35.0, 100.0].min

        # Weighted optimization cost (Lower score = Better route)
        opt_cost = (
          (norm_time * (weights["travel_time"] || 0.25)) +
          (norm_dist * (weights["distance"] || 0.10)) +
          (norm_risk * (weights["route_risk"] || 0.30)) +
          (norm_ml * (weights["ml_disruption"] || 0.25)) +
          (norm_incidents * (weights["incident_penalty"] || 0.10))
        )

        # Severe Blockage Penalty
        if route[:is_blocked]
          opt_cost += 500.0
        end

        route[:optimization_score] = opt_cost.round(2)
      end

      # Sort by ascending optimization score (lowest cost first)
      analyzed_routes.sort_by { |r| r[:optimization_score] }
    end

    def select_champion_route(ranked_routes)
      # Find lowest optimization cost that is not blocked
      champion = ranked_routes.find { |r| !r[:is_blocked] } || ranked_routes.first
      champion.dup
    end

    # =========================================================================
    # Explainable AI Recommendation
    # =========================================================================
    def build_explainable_recommendation(champion, all_routes)
      fastest_route = all_routes.min_by { |r| r[:enma_adjusted_eta_minutes] }
      safest_route = all_routes.min_by { |r| r[:route_risk_score] }
      runner_up = all_routes.reject { |r| r[:id] == champion[:id] }.first

      reasons = []
      positives = []
      warnings = []

      # Explain why champion won
      if champion[:is_blocked]
        warnings << "⚠ All analyzed corridors encounter active blockages. Proceed with emergency escort."
      else
        if champion[:route_risk_score] <= 25.0
          positives << "✓ Low overall corridor risk (#{champion[:route_risk_score]}/100)"
        end

        if champion[:ml_disruption_percentage] <= 25.0
          positives << "✓ Low ML disruption probability (#{champion[:ml_disruption_percentage]}%) over next 24 hours"
        elsif champion[:ml_disruption_percentage] < (fastest_route[:ml_disruption_percentage] || 50.0)
          diff_ml = (fastest_route[:ml_disruption_percentage] - champion[:ml_disruption_percentage]).round(1)
          positives << "✓ #{diff_ml}% lower ML disruption risk than fastest route"
        end

        if champion[:incident_count].zero?
          positives << "✓ Zero active field disaster reports on corridor"
        else
          positives << "✓ Avoids high-density disaster zones (#{champion[:incident_count]} nearby)"
        end

        if champion[:segment_breakdown][:critical_risk].zero?
          positives << "✓ No critical or impassable road segments"
        end
      end

      # Construct trade-off narrative
      tradeoff = if champion[:id] != fastest_route[:id] && !champion[:is_blocked]
                   time_diff = champion[:enma_adjusted_eta_minutes] - fastest_route[:enma_adjusted_eta_minutes]
                   dist_diff = (champion[:distance_km] - fastest_route[:distance_km]).round(1)
                   risk_diff = (fastest_route[:route_risk_score] - champion[:route_risk_score]).round(1)
                   "Although #{dist_diff > 0 ? "+#{dist_diff} km longer" : 'slightly longer'} (#{time_diff > 0 ? "+#{time_diff} mins" : ''}), #{champion[:title]} provides a #{risk_diff} point lower risk score and #{ (fastest_route[:ml_disruption_percentage] - champion[:ml_disruption_percentage]).round }% lower ML disruption probability."
                 elsif champion[:route_risk_score] <= 30.0
                   "#{champion[:title]} delivers optimal logistical efficiency with high corridor stability and minimal weather risk."
                 else
                   "#{champion[:title]} achieves the best balanced optimization score for #{priority_mode.titleize} priority under active monsoon conditions."
                 end

      {
        recommended_route_id: champion[:id],
        recommended_route_name: champion[:title],
        priority_mode: priority_mode,
        confidence_score: calculate_recommendation_confidence(champion),
        positives: positives,
        warnings: warnings,
        tradeoff_summary: tradeoff,
        summary: "ResQWay recommends #{champion[:title]} for #{cargo_type.downcase} transport."
      }
    end

    def calculate_recommendation_confidence(champion)
      base = 88.0
      base += 6.0 if champion[:route_risk_score] < 30.0
      base += 4.0 if champion[:ml_disruption_percentage] < 20.0
      base -= 15.0 if champion[:is_blocked]
      base.clamp(50.0, 99.0).round(1)
    end

    def calculate_delay_minutes(avg_road_risk, avg_ml_prob, weather_risk, incident_count, segments)
      delay = 0
      delay += (weather_risk * 0.25).round if weather_risk > 35.0
      delay += (incident_count * 15)
      delay += (avg_ml_prob * 30.0).round if avg_ml_prob > 0.40
      delay += 20 if segments.any? { |s| s[:road_condition] == "poor" || s[:road_condition] == "critical" }
      delay.clamp(0, 180)
    end

    def build_delay_reason(delay_mins, weather_risk, ml_prob, incident_count)
      return "Nominal corridor traffic flow." if delay_mins.zero?

      reasons = []
      reasons << "heavy rainfall" if weather_risk >= 50.0
      reasons << "#{incident_count} active field incident(s)" if incident_count > 0
      reasons << "high ML disruption probability" if ml_prob >= 0.50
      reasons << "degraded road pavement" if reasons.empty?

      "Estimated +#{delay_mins} mins delay due to #{reasons.join(', ')}."
    end

    def evaluate_incident_exposure(coords, incidents)
      return { intersected_count: 0 } if incidents.empty? || coords.empty?

      intersected = 0
      incidents.each do |inc|
        coords.each do |(lat, lon)|
          if calculate_haversine(lat, lon, inc.latitude, inc.longitude) <= 15.0
            intersected += 1
            break
          end
        end
      end
      { intersected_count: intersected }
    end

    def find_corridor_incidents
      return [] unless defined?(Incident)

      lat1, lon1 = extract_lat_lon(origin)
      lat2, lon2 = extract_lat_lon(destination)

      min_lat = [lat1, lat2].min - 0.5
      max_lat = [lat1, lat2].max + 0.5
      min_lon = [lon1, lon2].min - 0.5
      max_lon = [lon1, lon2].max + 0.5

      Incident.where(latitude: min_lat..max_lat, longitude: min_lon..max_lon).recent.limit(10).to_a
    end

    def find_corridor_emergencies
      return [] unless defined?(Emergency)

      lat1, lon1 = extract_lat_lon(origin)
      lat2, lon2 = extract_lat_lon(destination)

      min_lat = [lat1, lat2].min - 0.5
      max_lat = [lat1, lat2].max + 0.5
      min_lon = [lon1, lon2].min - 0.5
      max_lon = [lon1, lon2].max + 0.5

      Emergency.where(status: ["Active", "Responding", "Monitoring"])
               .where(latitude: min_lat..max_lat, longitude: min_lon..max_lon).to_a
    end

    def ensure_minimum_alternatives(routes)
      return routes if routes.size >= 3

      lat1, lon1 = extract_lat_lon(origin)
      lat2, lon2 = extract_lat_lon(destination)
      base_dist = routes.first&.dig(:distance_km) || calculate_haversine(lat1, lon1, lat2, lon2) * 1.3

      provider = Routing::FallbackProvider.new(options)
      if routes.size == 1
        synth = provider.calculate_routes(origin, destination, alternatives: true)
        routes << synth[1] if synth[1]
        routes << synth[2] if synth[2]
      elsif routes.size == 2
        synth = provider.calculate_routes(origin, destination, alternatives: true)
        routes << synth[2] if synth[2]
      end

      routes
    end

    def extract_lat_lon(loc)
      if loc.respond_to?(:latitude) && loc.respond_to?(:longitude)
        [loc.latitude.to_f, loc.longitude.to_f]
      elsif loc.is_a?(Array) && loc.size >= 2
        [loc[0].to_f, loc[1].to_f]
      elsif loc.is_a?(Hash)
        [loc[:latitude] || loc["latitude"] || loc[:lat] || loc["lat"],
         loc[:longitude] || loc["longitude"] || loc[:lon] || loc["lon"]]
      else
        [0.0, 0.0]
      end
    end

    def classify_risk(score)
      if score <= 25.0
        "LOW"
      elsif score <= 50.0
        "MODERATE"
      elsif score <= 75.0
        "HIGH"
      else
        "CRITICAL"
      end
    end

    def format_duration(hours)
      h = hours.floor
      m = ((hours - h) * 60).round
      if h > 0 && m > 0
        "#{h}h #{m}m"
      elsif h > 0
        "#{h}h"
      else
        "#{m}m"
      end
    end

    def check_network_partition(orig, dest)
      return { disconnected: false } unless defined?(ResQWay::NetworkConnectivityService)
      return { disconnected: false } unless orig.respond_to?(:id) && dest.respond_to?(:id) && orig.id.present? && dest.id.present?
      return { disconnected: false } if options[:skip_network_check]

      begin
        net_analysis = Rails.cache.fetch("resqway_network_connectivity_clusters", expires_in: 15.seconds) do
          ResQWay::NetworkConnectivityService.new.analyze(include_criticalities: false)
        end

        comps = net_analysis[:components] || []
        return { disconnected: false } if comps.empty?

        orig_comp = comps.find { |c| c[:node_ids]&.include?(orig.id) }
        dest_comp = comps.find { |c| c[:node_ids]&.include?(dest.id) }

        if orig_comp && dest_comp && orig_comp[:cluster_id] != dest_comp[:cluster_id]
          orig_name = orig.respond_to?(:name) ? orig.name : "Origin"
          dest_name = dest.respond_to?(:name) ? dest.name : "Destination"
          return {
            disconnected: true,
            reason: "Corridor severed by regional network partition: #{orig_name} and #{dest_name} reside in disconnected clusters with no passable overland route."
          }
        end
      rescue StandardError => e
        Rails.logger.warn("[RouteRecommendation] Network partition check error: #{e.message}")
      end

      { disconnected: false }
    end

    def self.calculate_haversine(lat1, lon1, lat2, lon2)
      return 0.0 if lat1.nil? || lon1.nil? || lat2.nil? || lon2.nil?

      dlat_rad = (lat2 - lat1) * Math::PI / 180.0
      dlon_rad = (lon2 - lon1) * Math::PI / 180.0
      lat1_rad = lat1 * Math::PI / 180.0
      lat2_rad = lat2 * Math::PI / 180.0

      a = (Math.sin(dlat_rad / 2.0)**2) +
          (Math.cos(lat1_rad) * Math.cos(lat2_rad) * (Math.sin(dlon_rad / 2.0)**2))
      c = 2.0 * Math.atan2(Math.sqrt(a), Math.sqrt(1.0 - a))
      EARTH_RADIUS_KM * c
    end

    def calculate_haversine(lat1, lon1, lat2, lon2)
      self.class.calculate_haversine(lat1, lon1, lat2, lon2)
    end
  end
end
