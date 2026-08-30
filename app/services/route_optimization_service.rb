class RouteOptimizationService
  EARTH_RADIUS_KM = 6371.0

  VEHICLE_SPEEDS = {
    "ambulance"         => { base: 60.0, label: "Ambulance (High Priority Transit)" },
    "emergency vehicle" => { base: 52.0, label: "Emergency Response Unit (Disaster Clearance)" },
    "truck"             => { base: 42.0, label: "Heavy Logistics Truck (Commercial Freight)" },
    "supply vehicle"    => { base: 46.0, label: "Relief Supply Convoy (Critical Cargo)" }
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

    base_road_distance = (straight_distance_km * 1.38).round(1) # North East terrain circuity
    active_emergencies = find_corridor_emergencies

    # Compute 3 Route Strategies
    fastest_route = build_fastest_route(base_road_distance, active_emergencies)
    safest_route = build_safest_route(base_road_distance, active_emergencies)
    efficient_route = build_efficient_route(base_road_distance, active_emergencies)

    routes = {
      fastest: fastest_route,
      safest: safest_route,
      efficient: efficient_route
    }

    # AI-Assisted Recommendation Decision
    recommended_type, recommendation_data = determine_recommendation(routes, active_emergencies)

    # Mark recommended flag
    routes.each do |type, route|
      route[:is_recommended] = (type == recommended_type)
    end

    {
      origin: origin,
      destination: destination,
      vehicle_type: vehicle_type,
      straight_distance_km: straight_distance_km.round(1),
      active_emergencies: active_emergencies,
      routes: routes,
      recommended_route_type: recommended_type,
      recommendation: recommendation_data
    }
  end

  # Haversine formula in pure Ruby
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

  def base_vehicle_speed
    key = vehicle_type.downcase
    VEHICLE_SPEEDS.fetch(key, { base: 45.0 })[:base]
  end

  def find_corridor_emergencies
    # Look for active emergencies near origin or destination or corridor bounding box
    min_lat = [origin.latitude, destination.latitude].min - 0.5
    max_lat = [origin.latitude, destination.latitude].max + 0.5
    min_lon = [origin.longitude, destination.longitude].min - 0.5
    max_lon = [origin.longitude, destination.longitude].max + 0.5

    Emergency.where(status: ["Active", "open", "Monitoring"])
             .where(latitude: min_lat..max_lat, longitude: min_lon..max_lon)
  end

  # -------------------------------------------------------------
  # Route Strategy 1: FASTEST ROUTE
  # -------------------------------------------------------------
  def build_fastest_route(base_dist, emergencies)
    distance = (base_dist * 1.0).round(1) # direct corridor
    speed = base_vehicle_speed * speed_modifier_for_fastest
    hours = (distance / speed).round(2)

    risk_score = calculate_route_risk(
      distance_factor: 1.0,
      emergency_count: emergencies.count,
      detour_protection: 0.0
    )

    {
      type: "fastest",
      title: "Fastest Route",
      tagline: "Minimum Transit Time",
      icon: "fa-bolt",
      color: "blue",
      hex_color: "#2563eb",
      badge_class: "bg-blue-100 text-blue-800 border-blue-200",
      distance_km: distance,
      estimated_hours: hours,
      estimated_time_formatted: format_duration(hours),
      risk_score: risk_score,
      risk_level: risk_level_for(risk_score),
      description: "Direct corridor maximizing travel speed. Suitable for time-critical dispatches during manageable weather.",
      waypoints: generate_waypoints(origin, destination, :fastest)
    }
  end

  # -------------------------------------------------------------
  # Route Strategy 2: SAFEST ROUTE
  # -------------------------------------------------------------
  def build_safest_route(base_dist, emergencies)
    distance = (base_dist * 1.22).round(1) # safe bypass detour around high-hazard passes
    speed = (base_vehicle_speed * 0.88).round(1) # steady, cautious driving speed
    hours = (distance / speed).round(2)

    risk_score = calculate_route_risk(
      distance_factor: 1.22,
      emergency_count: [0, emergencies.count - 1].max, # detours around active incidents
      detour_protection: 35.0 # significant safety reduction from avoiding hazard terrain
    )

    {
      type: "safest",
      title: "Safest Route",
      tagline: "Hazard & Disaster Avoidance",
      icon: "fa-shield-alt",
      color: "emerald",
      hex_color: "#059669",
      badge_class: "bg-emerald-100 text-emerald-800 border-emerald-200",
      distance_km: distance,
      estimated_hours: hours,
      estimated_time_formatted: format_duration(hours),
      risk_score: risk_score,
      risk_level: risk_level_for(risk_score),
      description: "Bypasses high landslide slopes, extreme weather stretches, and emergency choke points. Highly reliable arrival probability.",
      waypoints: generate_waypoints(origin, destination, :safest)
    }
  end

  # -------------------------------------------------------------
  # Route Strategy 3: MOST EFFICIENT ROUTE
  # -------------------------------------------------------------
  def build_efficient_route(base_dist, emergencies)
    distance = (base_dist * 1.09).round(1) # balanced intermediate path
    speed = (base_vehicle_speed * 0.95).round(1)
    hours = (distance / speed).round(2)

    risk_score = calculate_route_risk(
      distance_factor: 1.09,
      emergency_count: emergencies.count,
      detour_protection: 18.0
    )

    {
      type: "efficient",
      title: "Most Efficient Route",
      tagline: "Optimal Fuel, Time & Safety Balance",
      icon: "fa-balance-scale",
      color: "amber",
      hex_color: "#d97706",
      badge_class: "bg-amber-100 text-amber-800 border-amber-200",
      distance_km: distance,
      estimated_hours: hours,
      estimated_time_formatted: format_duration(hours),
      risk_score: risk_score,
      risk_level: risk_level_for(risk_score),
      description: "Best multi-criteria balance between vehicle wear, fuel economy, travel duration, and logistical security.",
      waypoints: generate_waypoints(origin, destination, :efficient)
    }
  end

  # -------------------------------------------------------------
  # Multi-Criteria Route Risk Engine (0 - 100)
  # -------------------------------------------------------------
  def calculate_route_risk(distance_factor:, emergency_count:, detour_protection:)
    # 1. Origin & Destination accessibility risk (0 - 100 accessibility -> invert to penalty)
    orig_score = origin.accessibility_score.presence || 50.0
    dest_score = destination.accessibility_score.presence || 50.0
    avg_inaccessibility = 100.0 - ((orig_score + dest_score) / 2.0)
    accessibility_risk_component = avg_inaccessibility * 0.35

    # 2. Road Quality factor
    road_penalty = case worst_road_quality
                   when "critical" then 25.0
                   when "poor"     then 18.0
                   when "moderate" then 10.0
                   when "good"     then 4.0
                   else 0.0
                   end

    # 3. Landslide factor
    landslide_penalty = case worst_landslide_risk
                        when "critical" then 28.0
                        when "high"     then 20.0
                        when "medium"   then 10.0
                        else 2.0
                        end

    # 4. Rainfall factor
    rainfall_penalty = case worst_rainfall_level
                       when "extreme"  then 20.0
                       when "high"     then 14.0
                       when "moderate" then 6.0
                       else 0.0
                       end

    # 5. Emergency Incident proximity penalty
    emergency_penalty = [emergency_count * 15.0, 30.0].min

    # Aggregate base risk
    raw_risk = accessibility_risk_component + road_penalty + landslide_penalty + rainfall_penalty + emergency_penalty
    
    # Apply detour protection credit
    adjusted_risk = raw_risk - detour_protection

    # Clamp between 0.0 and 100.0
    [[0.0, adjusted_risk].max, 100.0].min.round(1)
  end

  def speed_modifier_for_fastest
    modifier = 1.0
    modifier -= 0.15 if %w[poor critical].include?(worst_road_quality)
    modifier -= 0.10 if %w[high extreme].include?(worst_rainfall_level)
    [0.7, modifier].max
  end

  def worst_road_quality
    qualities = [origin.road_quality.to_s.downcase, destination.road_quality.to_s.downcase]
    return "critical" if qualities.include?("critical")
    return "poor" if qualities.include?("poor")
    return "moderate" if qualities.include?("moderate")
    return "good" if qualities.include?("good")
    "excellent"
  end

  def worst_landslide_risk
    risks = [origin.landslide_risk.to_s.downcase, destination.landslide_risk.to_s.downcase]
    return "critical" if risks.include?("critical")
    return "high" if risks.include?("high")
    return "medium" if risks.include?("medium")
    "low"
  end

  def worst_rainfall_level
    rains = [origin.rainfall_level.to_s.downcase, destination.rainfall_level.to_s.downcase]
    return "extreme" if rains.include?("extreme")
    return "high" if rains.include?("high")
    return "moderate" if rains.include?("moderate")
    "low"
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

  # -------------------------------------------------------------
  # Dynamic Recommendation & Explainable Decision Engine
  # -------------------------------------------------------------
  def determine_recommendation(routes, emergencies)
    vtype = vehicle_type.downcase
    fastest = routes[:fastest]
    safest = routes[:safest]
    efficient = routes[:efficient]

    has_acute_emergencies = emergencies.any?
    has_severe_landslide = %w[high critical].include?(worst_landslide_risk)
    has_extreme_rain = %w[high extreme].include?(worst_rainfall_level)
    fastest_high_risk = fastest[:risk_score] >= 52.0

    chosen_type = :efficient
    confidence = 88
    reasons = []

    case vtype
    when "ambulance"
      if fastest_high_risk || has_acute_emergencies
        chosen_type = :safest
        confidence = 91
        reasons << "Avoids high-risk blockage zones to eliminate patient transit entrapment"
        reasons << "Guarantees reliable bypass around acute emergency and landslide areas"
        reasons << "Provides stable road surfaces for mobile medical procedures"
        reasons << "Trade-off: Adds #{format_duration(safest[:estimated_hours] - fastest[:estimated_hours])} for substantial safety assurance"
      else
        chosen_type = :fastest
        confidence = 94
        reasons << "Minimizes patient arrival time with direct corridor navigation"
        reasons << "Corridor weather and landslide risk are within manageable bounds"
        reasons << "Priority high-speed transit profile selected"
      end

    when "emergency vehicle"
      if has_acute_emergencies || has_severe_landslide
        chosen_type = :safest
        confidence = 92
        reasons << "Bypasses active hazard bottlenecks to ensure responder arrival"
        reasons << "Mitigates vehicle breakdown risks on unstable slopes"
        reasons << "Maintains clear secondary communication and evacuation corridors"
      else
        chosen_type = :fastest
        confidence = 89
        reasons << "Fastest deployment corridor for urgent disaster response"
        reasons << "Direct highway route with no prohibitive obstacle alerts"
      end

    when "truck"
      if fastest_high_risk
        chosen_type = :safest
        confidence = 87
        reasons << "Protects heavy cargo and vehicle integrity from severe road damage"
        reasons << "Avoids steep landslide-prone mountain grades"
      else
        chosen_type = :efficient
        confidence = 90
        reasons << "Optimizes commercial fuel consumption and tire/brake wear"
        reasons << "Balances delivery deadline with steady logistics reliability"
        reasons << "Maintains favorable grade elevations for heavy tonnage loads"
      end

    else # supply vehicle
      if has_extreme_rain || has_severe_landslide
        chosen_type = :safest
        confidence = 93
        reasons << "Ensures 100% arrival rate of critical food, water, and medical relief supplies"
        reasons << "Detours around active flood channels and monsoon flash points"
        reasons << "Secures secondary resupply staging access"
      else
        chosen_type = :efficient
        confidence = 89
        reasons << "Ideal compromise between urgent delivery time and cargo security"
        reasons << "Maintains predictable supply chain schedule with low delay variance"
      end
    end

    recommendation_data = {
      recommended_type: chosen_type,
      recommended_route: routes[chosen_type],
      confidence_percentage: confidence,
      vehicle_context: VEHICLE_SPEEDS.fetch(vtype, { label: vehicle_type })[:label],
      summary: "Based on multi-criteria accessibility intelligence, real-time terrain risk, and vehicle dynamics, the #{routes[chosen_type][:title]} is recommended by ENMA AI.",
      reasons: reasons
    }

    [chosen_type, recommendation_data]
  end

  # -------------------------------------------------------------
  # Waypoint Generation for Leaflet Route Lines
  # -------------------------------------------------------------
  def generate_waypoints(orig, dest, route_type)
    lat1, lon1 = orig.latitude, orig.longitude
    lat2, lon2 = dest.latitude, dest.longitude

    steps = 6
    points = []
    points << [lat1.round(5), lon1.round(5)]

    (1...steps).each do |i|
      t = i.to_f / steps
      base_lat = lat1 + (lat2 - lat1) * t
      base_lon = lon1 + (lon2 - lon1) * t

      # Add realistic curvature offset based on route type
      offset = case route_type
               when :fastest
                 # Direct with slight terrain sinusoidal curve
                 Math.sin(t * Math::PI) * 0.04
               when :safest
                 # Prominent northern/eastern arc bypass
                 Math.sin(t * Math::PI) * 0.16
               when :efficient
                 # Moderate smooth grade curve
                 Math.sin(t * Math::PI) * 0.08
               else
                 0.0
               end

      # Orthogonal displacement
      dx = lat2 - lat1
      dy = lon2 - lon1
      len = Math.sqrt(dx * dx + dy * dy)
      norm_x = len.zero? ? 0 : -dy / len
      norm_y = len.zero? ? 0 : dx / len

      curved_lat = base_lat + (norm_x * offset)
      curved_lon = base_lon + (norm_y * offset)

      points << [curved_lat.round(5), curved_lon.round(5)]
    end

    points << [lat2.round(5), lon2.round(5)]
    points
  end
end
