class LogisticsReadinessService
  EARTH_RADIUS_KM = 6371.0

  attr_reader :locations, :warehouses, :emergencies

  def initialize(locations: nil, warehouses: nil, emergencies: nil)
    @locations = locations || Location.all
    @warehouses = warehouses || Warehouse.all
    @emergencies = emergencies || Emergency.all
  end

  def calculate
    return default_readiness if locations.empty?

    # 1. Average Accessibility Component (30%)
    avg_accessibility = locations.sum { |l| l.accessibility_score.to_f } / locations.size.to_f
    accessibility_component = avg_accessibility * 0.30

    # 2. Warehouse Coverage Component (25%)
    # Percentage of locations with at least one warehouse within 75 km, weighted with total capacity
    covered_locations = locations.count do |loc|
      warehouses.any? do |wh|
        haversine_distance(loc.latitude, loc.longitude, wh.latitude, wh.longitude) <= 75.0
      end
    end
    coverage_ratio = covered_locations / locations.size.to_f
    total_capacity = warehouses.sum(:capacity).to_f
    capacity_ratio = [[total_capacity / 120000.0, 1.0].min, 0.5].max
    warehouse_coverage_score = ((coverage_ratio * 0.7) + (capacity_ratio * 0.3)) * 100.0
    warehouse_component = warehouse_coverage_score * 0.25

    # 3. Emergency Preparedness Component (20%)
    # Evaluates active emergency containment & resolution throughput
    active_count = emergencies.count { |e| %w[Active open].include?(e.status) }
    critical_active = emergencies.count { |e| %w[Active open].include?(e.status) && e.severity.to_s.downcase == "critical" }
    emergency_deduction = (active_count * 8.0) + (critical_active * 12.0)
    emergency_prep_score = [[100.0 - emergency_deduction, 20.0].max, 100.0].min
    emergency_component = emergency_prep_score * 0.20

    # 4. Risk Resilience / Inverse Average Risk (25%)
    # Locations risk is derived from (100 - accessibility_score) and terrain factors
    avg_risk = locations.sum { |l| 100.0 - l.accessibility_score.to_f } / locations.size.to_f
    risk_resilience_score = [[100.0 - avg_risk, 0.0].max, 100.0].min
    risk_component = risk_resilience_score * 0.25

    # Final Total Readiness Score
    raw_score = accessibility_component + warehouse_component + emergency_component + risk_component
    final_score = [[0.0, raw_score].max, 100.0].min.round(1)

    category = category_for(final_score)
    explanation = generate_explanation(final_score, avg_accessibility, warehouse_coverage_score, emergency_prep_score, risk_resilience_score)
    recommendations = generate_recommendations(final_score, warehouse_coverage_score, avg_accessibility)

    {
      score: final_score,
      category: category,
      breakdown: {
        accessibility_percentage: avg_accessibility.round(1),
        warehouse_coverage_percentage: warehouse_coverage_score.round(1),
        emergency_preparedness_percentage: emergency_prep_score.round(1),
        risk_resilience_percentage: risk_resilience_score.round(1)
      },
      explanation: explanation,
      recommendation: recommendations
    }
  end

  private

  def category_for(score)
    if score >= 80.0
      "HIGHLY PREPARED"
    elsif score >= 60.0
      "PREPARED"
    elsif score >= 40.0
      "MODERATE READINESS"
    else
      "VULNERABLE"
    end
  end

  def generate_explanation(score, acc, wh, em, res)
    if score >= 80.0
      "Excellent regional logistics readiness with comprehensive strategic warehouse coverage (#{wh.round}%), robust valley transit corridors, and optimal active disaster containment."
    elsif score >= 60.0
      "Strong warehouse coverage (#{wh.round}%) and urban logistics networks support regional operations, but elevated seasonal landslide risks and remote mountain access constraints (#{acc.round}% avg access) moderate overall readiness."
    elsif score >= 40.0
      "Moderate operational readiness. Significant supply delivery delays expected in highland communities due to road infrastructure vulnerabilities and active hazard pressure."
    else
      "Critical vulnerability alert. Multiple communities face high isolation risk under active monsoon conditions. Urgent relief pre-positioning and forward mini-depot deployment required."
    end
  end

  def generate_recommendations(score, wh_cov, acc)
    if wh_cov < 70.0
      "Establish forward emergency distribution nodes (mini-depots) in remote mountain sectors like Tawang and Lachung to improve logistics reachability above 80%."
    elsif acc < 65.0
      "Prioritize road culvert reinforcement and secondary bypass corridor mapping with Border Roads Organisation to prevent arterial isolation during heavy rainfall."
    else
      "Maintain active telemetry monitoring, scheduled emergency convoy replenishment cycles, and standard hospital supply dispatch protocols."
    end
  end

  def haversine_distance(lat1, lon1, lat2, lon2)
    return 0.0 if lat1.nil? || lon1.nil? || lat2.nil? || lon2.nil?

    dlat = (lat2 - lat1) * Math::PI / 180.0
    dlon = (lon2 - lon1) * Math::PI / 180.0
    lat1_rad = lat1 * Math::PI / 180.0
    lat2_rad = lat2 * Math::PI / 180.0

    a = (Math.sin(dlat / 2.0)**2) + Math.cos(lat1_rad) * Math.cos(lat2_rad) * (Math.sin(dlon / 2.0)**2)
    c = 2.0 * Math.atan2(Math.sqrt(a), Math.sqrt(1.0 - a))
    EARTH_RADIUS_KM * c
  end

  def default_readiness
    {
      score: 50.0,
      category: "MODERATE READINESS",
      breakdown: {
        accessibility_percentage: 50.0,
        warehouse_coverage_percentage: 50.0,
        emergency_preparedness_percentage: 50.0,
        risk_resilience_percentage: 50.0
      },
      explanation: "Baseline readiness data.",
      recommendation: "Load regional location data to generate live intelligence."
    }
  end
end
