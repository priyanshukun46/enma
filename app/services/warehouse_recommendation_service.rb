class WarehouseRecommendationService
  EARTH_RADIUS_KM = 6371.0

  # Configurable weights
  WEIGHTS = {
    route_safety: 0.30,
    response_time: 0.25,
    resource_availability: 0.20,
    available_capacity: 0.15,
    operational_readiness: 0.10
  }.freeze

  attr_reader :emergency, :warehouses

  def initialize(emergency, warehouses: nil)
    @emergency = emergency
    @warehouses = warehouses || Warehouse.available.to_a
  end

  def recommend
    return empty_recommendation if warehouses.empty?

    candidates = warehouses.map { |wh| evaluate_candidate(wh) }
    candidates.sort_by! { |c| -c[:response_score] }
    candidates.each_with_index { |c, i| c[:rank] = i + 1 }

    best = candidates.first
    runner_up = candidates.second

    reasoning = generate_reasoning(best, runner_up)

    {
      recommended: best,
      candidates: candidates,
      reasoning: reasoning,
      weights: WEIGHTS,
      warehouse_count: candidates.size
    }
  end

  private

  def evaluate_candidate(wh)
    dist = haversine(emergency.latitude, emergency.longitude, wh.latitude, wh.longitude).round(1)

    # 1. Route Safety Score (0-100, higher is safer)
    route_data = fetch_route_safety(wh)
    route_risk = route_data[:risk_score] || estimate_risk_from_distance(dist)
    route_safety_score = (100.0 - route_risk).clamp(0.0, 100.0)

    # 2. Response Time Score (0-100, shorter is better)
    eta_hours = route_data[:eta_hours] || estimate_eta(dist)
    eta_formatted = format_eta(eta_hours)
    response_time_score = [(100.0 - (eta_hours * 12.0)), 0.0].max.clamp(0.0, 100.0)

    # 3. Resource Availability Score (0-100)
    resource_match = wh.emergency_type_resource_match(emergency.emergency_type)
    resource_score = resource_match.clamp(0.0, 100.0)

    # 4. Available Capacity Score (0-100)
    cap_ratio = wh.capacity.to_i > 0 ? (wh.available_capacity.to_f / wh.capacity.to_f) : 0.0
    capacity_score = (cap_ratio * 100.0).clamp(0.0, 100.0)

    # 5. Operational Readiness Score (0-100)
    status_multiplier = case wh.dynamic_status
                        when "OPERATIONAL" then 1.0
                        when "LIMITED" then 0.7
                        when "OVERLOADED" then 0.4
                        when "UNAVAILABLE" then 0.0
                        else 0.5
                        end
    readiness_base = wh.readiness_score || wh.calculate_readiness_score
    readiness_score = (readiness_base * status_multiplier).clamp(0.0, 100.0)

    # Weighted composite
    response_score = (
      (route_safety_score * WEIGHTS[:route_safety]) +
      (response_time_score * WEIGHTS[:response_time]) +
      (resource_score * WEIGHTS[:resource_availability]) +
      (capacity_score * WEIGHTS[:available_capacity]) +
      (readiness_score * WEIGHTS[:operational_readiness])
    ).round(1)

    # Generate factor badges
    positive_factors = []
    negative_factors = []

    positive_factors << "✓ Safe emergency dispatch corridor (Risk: #{route_risk.round(0)}/100)" if route_safety_score >= 65.0
    positive_factors << "✓ Fast response time (ETA: #{eta_formatted})" if response_time_score >= 60.0
    positive_factors << "✓ Strong #{emergency.emergency_type.downcase} resource availability" if resource_score >= 65.0
    positive_factors << "✓ Adequate spare capacity (#{wh.utilization_percentage}% utilized)" if capacity_score >= 40.0
    positive_factors << "✓ Fully operational status" if wh.dynamic_status == "OPERATIONAL"

    negative_factors << "⚠ High-risk dispatch corridor (Risk: #{route_risk.round(0)}/100)" if route_safety_score < 50.0
    negative_factors << "⚠ Extended response time (ETA: #{eta_formatted})" if response_time_score < 40.0
    negative_factors << "⚠ Limited #{emergency.emergency_type.downcase} resource stocks" if resource_score < 40.0
    negative_factors << "⚠ Near or at capacity (#{wh.utilization_percentage}% utilized)" if capacity_score < 25.0
    negative_factors << "⚠ #{wh.dynamic_status} operational status" if wh.dynamic_status != "OPERATIONAL"

    {
      warehouse: wh,
      id: wh.id,
      name: wh.name,
      latitude: wh.latitude,
      longitude: wh.longitude,
      capacity: wh.capacity,
      available_capacity: wh.available_capacity,
      utilized_capacity: wh.utilized_capacity,
      utilization_percentage: wh.utilization_percentage,
      operational_status: wh.dynamic_status,
      readiness_score: readiness_base.round(1),
      resources: wh.resources,
      total_available_resources: wh.total_available_resources,
      distance_km: dist,
      route_risk: route_risk.round(1),
      route_safety_score: route_safety_score.round(1),
      response_time_score: response_time_score.round(1),
      resource_score: resource_score.round(1),
      capacity_score: capacity_score.round(1),
      readiness_component: readiness_score.round(1),
      response_score: response_score,
      eta_hours: eta_hours.round(2),
      eta_formatted: eta_formatted,
      positive_factors: positive_factors,
      negative_factors: negative_factors,
      recommendation_score: response_score,
      status_badge_class: wh.status_badge_class,
      selection_reasoning: ""
    }
  end

  def fetch_route_safety(wh)
    if Rails.env.test? && !ENV["ENABLE_NETWORK_TESTS"]
      dist = haversine(wh.latitude, wh.longitude, emergency.latitude, emergency.longitude)
      return {
        risk_score: estimate_risk_from_distance(dist),
        eta_hours: estimate_eta(dist)
      }
    end

    # Find closest location proxy for warehouse
    wh_proxy = wh.location || Location.all.min_by { |loc|
      haversine(wh.latitude, wh.longitude, loc.latitude, loc.longitude)
    }
    target = emergency.location || Location.all.min_by { |loc|
      haversine(emergency.latitude, emergency.longitude, loc.latitude, loc.longitude)
    }

    return { risk_score: 30.0, eta_hours: 3.0 } unless wh_proxy && target && wh_proxy.id != target.id

    begin
      service = RouteOptimizationService.new(
        origin: wh_proxy,
        destination: target,
        vehicle_type: "Emergency Vehicle"
      )
      result = service.calculate
      safest = result[:routes][:safest] || result[:routes].values.first
      {
        risk_score: safest[:risk_score] || 30.0,
        eta_hours: safest[:estimated_hours] || 3.0
      }
    rescue StandardError => _e
      dist = haversine(wh.latitude, wh.longitude, emergency.latitude, emergency.longitude)
      { risk_score: estimate_risk_from_distance(dist), eta_hours: estimate_eta(dist) }
    end
  end

  def estimate_risk_from_distance(dist)
    [(dist * 0.15), 60.0].min
  end

  def estimate_eta(dist)
    (dist / 45.0).round(2)
  end

  def format_eta(hours)
    h = hours.floor
    m = ((hours - h) * 60).round
    h > 0 ? "#{h}h #{m}m" : "#{m}m"
  end

  def generate_reasoning(best, runner_up)
    return "#{best[:name]} is the only available warehouse and is recommended for immediate emergency deployment." unless runner_up

    parts = []
    parts << "#{best[:name]} is recommended"

    advantages = []
    advantages << "significantly safer emergency route (Risk: #{best[:route_risk]}/100 vs #{runner_up[:route_risk]}/100)" if best[:route_safety_score] > runner_up[:route_safety_score] + 10
    advantages << "better #{emergency.emergency_type.downcase} resource availability" if best[:resource_score] > runner_up[:resource_score] + 10
    advantages << "more available capacity (#{best[:utilization_percentage]}% vs #{runner_up[:utilization_percentage]}% utilized)" if best[:capacity_score] > runner_up[:capacity_score] + 10
    advantages << "faster estimated response (#{best[:eta_formatted]} vs #{runner_up[:eta_formatted]})" if best[:response_time_score] > runner_up[:response_time_score] + 10
    advantages << "fully operational status" if best[:operational_status] == "OPERATIONAL" && runner_up[:operational_status] != "OPERATIONAL"

    if advantages.any?
      parts << "because it provides #{advantages.join(', ')}"
    else
      parts << "as it achieves the highest overall response score (#{best[:response_score]}/100)"
    end

    if runner_up[:distance_km] < best[:distance_km]
      parts << "despite #{runner_up[:name]} being closer (#{runner_up[:distance_km]} km vs #{best[:distance_km]} km)"
    end

    parts.join(" ") + "."
  end

  def empty_recommendation
    {
      recommended: nil,
      candidates: [],
      reasoning: "No available warehouses found in the system.",
      weights: WEIGHTS,
      warehouse_count: 0
    }
  end

  def haversine(lat1, lon1, lat2, lon2)
    return 0.0 if lat1.nil? || lon1.nil? || lat2.nil? || lon2.nil?
    dlat = (lat2 - lat1) * Math::PI / 180.0
    dlon = (lon2 - lon1) * Math::PI / 180.0
    a = Math.sin(dlat / 2.0)**2 + Math.cos(lat1 * Math::PI / 180.0) * Math.cos(lat2 * Math::PI / 180.0) * Math.sin(dlon / 2.0)**2
    EARTH_RADIUS_KM * 2.0 * Math.atan2(Math.sqrt(a), Math.sqrt(1.0 - a))
  end
end
