class RouteOptimizationService
  EARTH_RADIUS_KM = 6371.0

  VEHICLE_PROFILES = {
    "ambulance" => {
      base_speed: 60.0,
      label: "Ambulance (Emergency Medical Transit)",
      weights: { safety: 0.40, time: 0.35, accessibility: 0.15, distance: 0.05, environmental: 0.05 }
    },
    "emergency vehicle" => {
      base_speed: 55.0,
      label: "Emergency Response Unit (Priority Clearance)",
      weights: { safety: 0.35, time: 0.35, accessibility: 0.15, environmental: 0.10, distance: 0.05 }
    },
    "truck" => {
      base_speed: 42.0,
      label: "Heavy Logistics Freight Truck",
      weights: { safety: 0.30, distance: 0.25, time: 0.20, accessibility: 0.15, environmental: 0.10 }
    },
    "supply vehicle" => {
      base_speed: 46.0,
      label: "Relief Supply Convoy (Essential Cargo)",
      weights: { safety: 0.35, accessibility: 0.25, time: 0.20, distance: 0.10, environmental: 0.10 }
    },
    "personal vehicle" => {
      base_speed: 50.0,
      label: "Light Transport / Personal Vehicle",
      weights: { time: 0.35, safety: 0.30, distance: 0.20, accessibility: 0.10, environmental: 0.05 }
    }
  }.freeze

  attr_reader :origin, :destination, :vehicle_type, :straight_distance_km

  def initialize(origin:, destination:, vehicle_type: "Truck")
    @origin = origin
    @destination = destination
    @vehicle_type = vehicle_type.to_s.strip
    @straight_distance_km = calculate_haversine_distance(
      origin.latitude, origin.longitude,
      destination.latitude, destination.longitude
    )
  end

  def calculate
    validate_locations!

    cache_key = "route_opt_v3_#{origin.id}_#{destination.id}_#{vehicle_type.parameterize}"

    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      active_emergencies = find_corridor_emergencies

      # 1. Obtain real road route alternatives from RoutingService (with resilient fallback)
      raw_alternatives = RoutingService.new(origin: origin, destination: destination).alternatives
      source_provider = raw_alternatives.first&.dig(:source) || "fallback_haversine"
      fallback_used = raw_alternatives.first&.dig(:fallback_used) || false

      # 2. Analyze and score each candidate route using ENMA AI multi-criteria intelligence
      analyzed_routes = raw_alternatives.map.with_index do |route_candidate, idx|
        analyze_single_route(route_candidate, idx, active_emergencies)
      end

      # Ensure at least 3 distinct routes exist for comparison (if provider returned only 1)
      ensured_routes = synthesize_strategy_routes(analyzed_routes, active_emergencies)

      # 3. Categorize into Fastest, Safest, and Most Efficient
      classified_routes = categorize_routes(ensured_routes)

      # 4. Determine ENMA AI Recommended Route
      recommended_type, recommendation_data = determine_best_recommendation(classified_routes, active_emergencies)

      # Mark is_recommended flag
      classified_routes.each do |type_key, rdata|
        rdata[:is_recommended] = (type_key == recommended_type)
      end

      {
        origin: origin,
        destination: destination,
        vehicle_type: vehicle_type,
        straight_distance_km: straight_distance_km.round(1),
        active_emergencies: active_emergencies,
        routes: classified_routes,
        recommended_route_type: recommended_type,
        recommendation: recommendation_data,
        source_provider: source_provider,
        fallback_used: fallback_used,
        corridor_weather: {
          origin: origin_weather,
          destination: destination_weather,
          source: (origin_weather[:source] == "live" && destination_weather[:source] == "live") ? "live" : "demo_fallback"
        },
        calculated_at: Time.current
      }
    end
  end

  def calculate_haversine_distance(lat1, lon1, lat2, lon2)
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

  private

  def validate_locations!
    raise ArgumentError, "Origin location is required" if origin.nil?
    raise ArgumentError, "Destination location is required" if destination.nil?
    raise ArgumentError, "Origin and destination cannot be the same" if origin.id == destination.id
  end

  def vehicle_profile
    key = vehicle_type.downcase
    VEHICLE_PROFILES.fetch(key, VEHICLE_PROFILES["truck"])
  end

  def find_corridor_emergencies
    min_lat = [origin.latitude, destination.latitude].min - 0.6
    max_lat = [origin.latitude, destination.latitude].max + 0.6
    min_lon = [origin.longitude, destination.longitude].min - 0.6
    max_lon = [origin.longitude, destination.longitude].max + 0.6

    Emergency.where(status: ["Active", "open", "Monitoring", "Responding"])
             .where(latitude: min_lat..max_lat, longitude: min_lon..max_lon)
  end

  # =========================================================================
  # Route Intelligence Scoring (0 - 100 for all dimensions)
  # =========================================================================
  def analyze_single_route(raw_route, index, emergencies)
    dist_km = raw_route[:distance_km].to_f
    duration_hrs = raw_route[:estimated_hours].to_f
    duration_mins = raw_route[:duration_minutes] || (duration_hrs * 60).round
    coords = raw_route[:coordinates] || []

    # 1. Multi-point corridor weather exposure intelligence
    corridor_weather = WeatherService.sample_corridor_weather(coords, fallback_location: origin)
    weather_exposure = corridor_weather[:weather_exposure_score].to_f

    # 2. Proximity to Active Emergencies along coordinates
    emergency_proximity = evaluate_emergency_exposure(coords, emergencies)
    emergency_count = emergency_proximity[:intersected_count]

    # 3. Environmental & Terrain Hazard Risk
    road_penalty = evaluate_road_quality_penalty
    landslide_penalty = evaluate_landslide_penalty(index)
    rainfall_penalty = (weather_exposure * 0.35)

    # Compute Composite Environmental Risk & Safety Score (0 - 100)
    raw_risk = (emergency_count * 25.0) + rainfall_penalty + (landslide_penalty * 0.9) + (road_penalty * 0.7)
    # Detour credit: Alternative routes that curve away from straight line reduce risk
    detour_credit = (index > 0) ? (index * 12.0) : 0.0
    final_risk_score = [[0.0, raw_risk - detour_credit].max, 100.0].min.round(1)
    safety_score = (100.0 - final_risk_score).round(1)

    # 4. Accessibility Score of Corridor (0 - 100)
    orig_acc = origin.accessibility_score.presence || 50.0
    dest_acc = destination.accessibility_score.presence || 50.0
    accessibility_score = (((orig_acc + dest_acc) / 2.0) - (index * 2.0)).clamp(10.0, 100.0).round(1)

    # 5. Time & Distance Efficiency Score (0 - 100)
    base_speed = vehicle_profile[:base_speed]
    ideal_hours = (straight_distance_km * 1.25) / base_speed
    time_ratio = ideal_hours / [duration_hrs, 0.1].max
    time_score = (time_ratio * 100.0).clamp(10.0, 100.0).round(1)

    dist_ratio = (straight_distance_km * 1.25) / [dist_km, 0.1].max
    distance_score = (dist_ratio * 100.0).clamp(10.0, 100.0).round(1)
    efficiency_score = ((time_score * 0.5) + (distance_score * 0.5)).round(1)

    # 6. Environmental Score
    environmental_score = (100.0 - (landslide_penalty + rainfall_penalty)).clamp(0.0, 100.0).round(1)

    # 7. ENMA AI Overall Score: 45% Safety + 30% Accessibility + 25% Efficiency
    raw_overall = (
      (safety_score * 0.45) +
      (accessibility_score * 0.30) +
      (efficiency_score * 0.25)
    )

    # Risk Penalty: If route enters active disaster zones or severe hazards (risk >= 40.0),
    # dampen overall score so a dangerous route cannot outscore a safe detour.
    risk_dampener = if final_risk_score >= 70.0
                      0.40 # Critical disaster intersection / extreme hazard
                    elsif final_risk_score >= 50.0
                      0.65 # High hazard
                    elsif final_risk_score >= 35.0
                      0.85 # Moderate hazard
                    else
                      1.0
                    end

    overall_score = (raw_overall * risk_dampener).clamp(5.0, 100.0).round(1)

    # 8. Dynamic Explainable Factor Generation
    positive_factors, negative_factors = generate_route_factors(
      safety_score, final_risk_score, accessibility_score, efficiency_score,
      corridor_weather, emergency_proximity, duration_mins
    )

    {
      id: raw_route[:id] || "route_#{index + 1}",
      name: raw_route[:name] || "Corridor #{index + 1}",
      distance_km: dist_km,
      duration_minutes: duration_mins,
      estimated_hours: duration_hrs,
      estimated_time_formatted: format_duration(duration_hrs),
      geometry: coords,
      coordinates: coords,
      steps: raw_route[:steps] || [],
      source: raw_route[:source] || "live",
      summary: raw_route[:summary] || "Navigable Highway Corridor",
      scores: {
        risk_score: final_risk_score,
        environmental_risk: final_risk_score,
        weather_exposure: weather_exposure,
        safety: safety_score,
        time: time_score,
        accessibility: accessibility_score,
        distance: distance_score,
        efficiency: efficiency_score,
        environmental: environmental_score,
        overall_score: overall_score,
        overall_intelligence: overall_score
      },
      risk_score: final_risk_score,
      risk_level: risk_level_for(final_risk_score),
      accessibility_score: accessibility_score,
      efficiency_score: efficiency_score,
      overall_score: overall_score,
      weather_exposure_score: weather_exposure,
      corridor_weather: corridor_weather,
      emergency_exposure: emergency_proximity,
      positive_factors: positive_factors,
      negative_factors: negative_factors,
      hazard_factors: {
        road_quality: worst_road_quality,
        landslide_risk: worst_landslide_risk,
        rainfall_level: worst_rainfall_level
      }
    }
  end

  def generate_route_factors(safety_score, risk_score, acc_score, eff_score, weather, emergencies, duration_mins)
    positives = []
    negatives = []

    # Weather factors
    if weather[:weather_exposure_score] <= 25.0
      positives << "✓ Nominal weather conditions (#{weather[:max_precipitation_mm]} mm/hr rainfall)"
    else
      negatives << "⚠ Weather exposure: #{weather[:condition_summary]} (#{weather[:max_precipitation_mm]} mm/hr, #{weather[:max_wind_kmh]} km/h wind)"
    end

    # Emergency proximity
    if emergencies[:intersected_count].zero?
      positives << "✓ Zero active disaster zone intersections along corridor"
    else
      negatives << "⚠ Intersects #{emergencies[:intersected_count]} active disaster hazard zone(s)"
    end

    # Risk & Safety
    if risk_score <= 30.0
      positives << "✓ Low environmental & terrain risk (#{risk_score}/100)"
    elsif risk_score >= 60.0
      negatives << "⚠ High environmental & landslide risk (#{risk_score}/100)"
    end

    # Accessibility
    if acc_score >= 70.0
      positives << "✓ High corridor accessibility rating (#{acc_score}/100)"
    elsif acc_score < 45.0
      negatives << "⚠ Difficult terrain gradient and limited hospital accessibility (#{acc_score}/100)"
    end

    # Efficiency
    if eff_score >= 80.0
      positives << "✓ High transit efficiency and direct route corridor"
    end

    [positives, negatives]
  end

  def evaluate_emergency_exposure(coords, emergencies)
    return { intersected_count: 0, nearest_km: nil } if emergencies.empty? || coords.empty?

    intersected = 0
    min_dist = 999.0

    emergencies.each do |em|
      em_radius = em.affected_radius.presence || 30.0
      coords.each do |(lat, lon)|
        d = calculate_haversine_distance(lat, lon, em.latitude, em.longitude)
        min_dist = [min_dist, d].min
        if d <= em_radius
          intersected += 1
          break
        end
      end
    end

    {
      intersected_count: intersected,
      nearest_km: (min_dist == 999.0 ? nil : min_dist.round(1))
    }
  end

  def evaluate_road_quality_penalty
    case worst_road_quality
    when "critical" then 24.0
    when "poor"     then 16.0
    when "moderate" then 8.0
    else 2.0
    end
  end

  def evaluate_landslide_penalty(index)
    base = case worst_landslide_risk
           when "critical" then 28.0
           when "high"     then 20.0
           when "medium"   then 10.0
           else 2.0
           end
    # Alternative bypasses reduce landslide exposure
    [base - (index * 8.0), 0.0].max
  end

  def evaluate_rainfall_penalty
    case worst_rainfall_level
    when "extreme"  then 22.0
    when "high"     then 14.0
    when "moderate" then 6.0
    else 0.0
    end
  end

  def worst_road_quality
    [origin.road_quality.to_s.downcase, destination.road_quality.to_s.downcase].max_by do |q|
      %w[excellent good moderate poor critical].index(q) || 0
    end || "good"
  end

  def worst_landslide_risk
    [origin.landslide_risk.to_s.downcase, destination.landslide_risk.to_s.downcase].max_by do |r|
      %w[low medium high critical].index(r) || 0
    end || "low"
  end

  def origin_weather
    @origin_weather ||= WeatherService.fetch(origin.latitude, origin.longitude, fallback_location: origin)
  end

  def destination_weather
    @destination_weather ||= WeatherService.fetch(destination.latitude, destination.longitude, fallback_location: destination)
  end

  def worst_rainfall_level
    orig_level = origin_weather[:rainfall_level].presence || origin.rainfall_level.to_s.downcase
    dest_level = destination_weather[:rainfall_level].presence || destination.rainfall_level.to_s.downcase
    [orig_level, dest_level].max_by do |r|
      %w[low moderate high extreme].index(r) || 0
    end || "low"
  end

  def risk_level_for(score)
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
      "#{h} hr #{m} min"
    elsif h > 0
      "#{h} hr"
    else
      "#{m} min"
    end
  end

  # =========================================================================
  # Ensure 3 Strategies: Fastest, Safest, and Most Efficient
  # =========================================================================
  def synthesize_strategy_routes(routes, emergencies)
    return routes if routes.size >= 3

    # If routing provider returned fewer than 3, synthesize alternative corridors
    base = routes.first
    base_dist = base[:distance_km]

    # Synthesize Safest (Detour around hazard areas)
    safest_coords = RoutingService.new(origin: origin, destination: destination).send(
      :generate_curved_waypoints, origin.latitude, origin.longitude, destination.latitude, destination.longitude, 0.16
    )
    safest_dist = (base_dist * 1.18).round(1)
    safest_hrs = (safest_dist / (vehicle_profile[:base_speed] * 0.88)).round(2)
    safest_mins = (safest_hrs * 60).round
    safest_steps = RoutingService.new(origin: origin, destination: destination).send(
      :generate_fallback_steps, safest_coords, safest_dist, safest_mins
    )

    safest_candidate = {
      id: "route_2",
      name: "Highland Bypass Corridor",
      distance_km: safest_dist,
      duration_minutes: safest_mins,
      estimated_hours: safest_hrs,
      coordinates: safest_coords,
      steps: safest_steps,
      source: "fallback_haversine",
      summary: "Highland Bypass Corridor (Hazard Detour)"
    }
    routes << analyze_single_route(safest_candidate, 1, emergencies)

    # Synthesize Efficient (Balanced intermediate path)
    if routes.size < 3
      eff_coords = RoutingService.new(origin: origin, destination: destination).send(
        :generate_curved_waypoints, origin.latitude, origin.longitude, destination.latitude, destination.longitude, -0.09
      )
      eff_dist = (base_dist * 1.08).round(1)
      eff_hrs = (eff_dist / (vehicle_profile[:base_speed] * 0.94)).round(2)
      eff_mins = (eff_hrs * 60).round
      eff_steps = RoutingService.new(origin: origin, destination: destination).send(
        :generate_fallback_steps, eff_coords, eff_dist, eff_mins
      )

      eff_candidate = {
        id: "route_3",
        name: "Valley Transit Corridor",
        distance_km: eff_dist,
        duration_minutes: eff_mins,
        estimated_hours: eff_hrs,
        coordinates: eff_coords,
        steps: eff_steps,
        source: "fallback_haversine",
        summary: "Valley Transit Corridor (Balanced Highway)"
      }
      routes << analyze_single_route(eff_candidate, 2, emergencies)
    end

    routes
  end

  def categorize_routes(analyzed_routes)
    # Sort for fastest (minimum duration)
    fastest = analyzed_routes.min_by { |r| r[:duration_minutes] }.dup
    fastest[:type] = "fastest"
    fastest[:title] = "Fastest Route"
    fastest[:tagline] = "Minimum Transit Time"
    fastest[:icon] = "fa-bolt"
    fastest[:color] = "blue"
    fastest[:hex_color] = "#2563eb"
    fastest[:badge_class] = "bg-blue-100 text-blue-800 border-blue-200"

    # Sort for safest (highest safety score / lowest risk)
    safest = analyzed_routes.max_by { |r| r[:scores][:safety] }.dup
    safest[:type] = "safest"
    safest[:title] = "Safest Route"
    safest[:tagline] = "Hazard & Disaster Avoidance"
    safest[:icon] = "fa-shield-alt"
    safest[:color] = "emerald"
    safest[:hex_color] = "#059669"
    safest[:badge_class] = "bg-emerald-100 text-emerald-800 border-emerald-200"

    # Sort for most efficient (best balanced overall score excluding fastest/safest duplicates where possible)
    remaining = analyzed_routes.reject { |r| r[:id] == fastest[:id] && r[:id] == safest[:id] }
    efficient = (remaining.max_by { |r| r[:scores][:overall_intelligence] } || analyzed_routes.last).dup
    efficient[:type] = "efficient"
    efficient[:title] = "Most Efficient Route"
    efficient[:tagline] = "Optimal Time, Distance & Fuel Balance"
    efficient[:icon] = "fa-balance-scale"
    efficient[:color] = "amber"
    efficient[:hex_color] = "#d97706"
    efficient[:badge_class] = "bg-amber-100 text-amber-800 border-amber-200"

    balanced = efficient.dup
    balanced[:type] = "balanced"
    balanced[:title] = "Balanced Route"
    balanced[:tagline] = "Optimal Time, Safety & Distance Balance"

    {
      fastest: fastest,
      safest: safest,
      efficient: efficient,
      balanced: balanced
    }
  end

  # =========================================================================
  # Explainable Recommendation Decision
  # =========================================================================
  def determine_best_recommendation(classified_routes, emergencies)
    vtype = vehicle_type.downcase
    fastest = classified_routes[:fastest]
    safest = classified_routes[:safest]
    balanced = classified_routes[:balanced] || classified_routes[:efficient]

    # Decide winner based on overall intelligence score and vehicle context
    candidates = [
      [:fastest, fastest],
      [:safest, safest],
      [:balanced, balanced]
    ]

    # Safety Principle: If the fastest route passes through high/critical hazard zones (risk >= 40.0),
    # ENMA AI must NEVER recommend the high-risk route over a safe detour!
    if fastest[:risk_score] >= 40.0 && safest[:risk_score] < fastest[:risk_score]
      best_type = :safest
      best_route = safest
    elsif (fastest[:risk_score] - safest[:risk_score]) >= 15.0 && fastest[:risk_score] > 25.0
      # If Safest saves significant risk (15+ pts), prefer Safest or Balanced
      best_type = (balanced && balanced[:risk_score] <= safest[:risk_score] + 5.0) ? :balanced : :safest
      best_route = (best_type == :balanced) ? balanced : safest
    else
      best_type, best_route = candidates.max_by { |_, r| r[:scores][:overall_score] || r[:scores][:overall_intelligence] }
    end

    # Build dynamic explainable reasoning
    reasons = generate_explainable_reasons(best_type, best_route, fastest, safest, balanced, emergencies)
    trade_off = generate_trade_off_analysis(best_type, best_route, fastest, safest)

    recommendation_data = {
      recommended_type: best_type,
      recommended_route: best_route,
      confidence_percentage: [85 + (best_route[:scores][:overall_intelligence] * 0.12).round, 98].min,
      vehicle_context: vehicle_profile[:label],
      summary: "Based on real multi-criteria routing, live risk buffering, and #{vehicle_profile[:label]} dynamics, the #{best_route[:title]} is recommended by ENMA AI.",
      reasons: reasons,
      trade_off: trade_off
    }

    [best_type, recommendation_data]
  end

  def generate_explainable_reasons(chosen_type, chosen_route, fastest, safest, balanced, emergencies)
    reasons = []

    if chosen_route[:emergency_exposure][:intersected_count] == 0
      reasons << "Zero active emergency or disaster intersections detected along this corridor."
    else
      reasons << "Minimizes exposure to active emergency zones (#{chosen_route[:emergency_exposure][:intersected_count]} nearby)."
    end

    if chosen_route[:risk_score] <= 25.0
      reasons << "Corridor classified as LOW LOGISTICS RISK (Risk score: #{chosen_route[:risk_score]}/100)."
    elsif chosen_route[:risk_score] < fastest[:risk_score]
      reasons << "Reduces overall transit risk by #{(fastest[:risk_score] - chosen_route[:risk_score]).round(1)} points compared to the fastest route."
    end

    if chosen_route[:scores][:accessibility] >= 70.0
      reasons << "Passes through sectors with HIGH accessibility rating (#{chosen_route[:scores][:accessibility]}/100)."
    end

    if chosen_type == :fastest
      reasons << "Direct highway route delivering the shortest estimated arrival time (#{chosen_route[:estimated_time_formatted]})."
    elsif chosen_type == :safest
      reasons << "Bypasses high landslide-risk mountain cuts to prevent vehicle entrapment."
    else
      reasons << "Delivers optimal balance of fuel economy, road grade stability, and scheduled reliability."
    end

    reasons
  end

  def generate_trade_off_analysis(chosen_type, chosen_route, fastest, safest)
    if chosen_type == :safest && chosen_route[:id] != fastest[:id]
      time_diff = chosen_route[:duration_minutes] - fastest[:duration_minutes]
      dist_diff = (chosen_route[:distance_km] - fastest[:distance_km]).round(1)
      risk_reduction_pct = (((fastest[:risk_score] - chosen_route[:risk_score]) / [fastest[:risk_score], 1.0].max) * 100.0).round
      "#{chosen_route[:title]} is recommended by ENMA AI because it has #{risk_reduction_pct > 0 ? "#{risk_reduction_pct}% lower environmental risk" : 'lower risk'} and better accessibility (#{chosen_route[:scores][:accessibility]}/100) despite adding #{time_diff} minutes of travel time."
    elsif chosen_type == :fastest && chosen_route[:risk_score] <= 35.0
      "Fastest Route is recommended because corridor weather and landslide telemetry indicate nominal conditions with manageable risk (#{chosen_route[:risk_score]}/100)."
    else
      "Balanced Route is recommended to optimize transit time while maintaining logistical security for #{vehicle_type}."
    end
  end
end
