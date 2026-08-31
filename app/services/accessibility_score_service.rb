class AccessibilityScoreService
  BASE_SCORE = 100.0

  ROAD_PENALTIES = {
    "excellent" => 0,
    "good"      => 5,
    "moderate"  => 15,
    "poor"      => 30,
    "critical"  => 45
  }.freeze

  RAINFALL_PENALTIES = {
    "low"               => 0,
    "low rainfall"      => 0,
    "moderate"          => 5,
    "moderate rainfall" => 5,
    "high"              => 15,
    "high rainfall"     => 15,
    "extreme"           => 25,
    "extreme rainfall"  => 25
  }.freeze

  LANDSLIDE_PENALTIES = {
    "low"      => 0,
    "medium"   => 10,
    "moderate" => 10,
    "high"     => 25,
    "critical" => 40
  }.freeze

  TRANSPORT_PENALTIES = {
    "high"   => 0,
    "medium" => 10,
    "low"    => 25
  }.freeze

  attr_reader :location

  def initialize(location)
    @location = location
  end

  def calculate
    breakdown = factor_breakdown
    total_penalty = breakdown.values.sum { |f| f[:impact].abs }
    raw_score = BASE_SCORE - total_penalty
    final_score = [[0.0, raw_score].max, 100.0].min.round(1)

    category = category_for(final_score)
    risk_level = risk_level_for(final_score)
    primary_factor = identify_primary_risk_factor(breakdown)

    {
      score: final_score,
      category: category,
      risk_level: risk_level,
      primary_risk_factor: primary_factor,
      factors: breakdown
    }
  end

  def self.category_for(score)
    new(nil).category_for(score)
  end

  def self.risk_level_for(score)
    new(nil).risk_level_for(score)
  end

  def category_for(score)
    return "Critical Accessibility" if score.nil?

    if score >= 80.0
      "Highly Accessible"
    elsif score >= 60.0
      "Moderately Accessible"
    elsif score >= 40.0
      "Difficult Access"
    else
      "Critical Accessibility"
    end
  end

  def risk_level_for(score)
    return "CRITICAL" if score.nil?

    if score >= 80.0
      "LOW"
    elsif score >= 60.0
      "MODERATE"
    elsif score >= 40.0
      "HIGH"
    else
      "CRITICAL"
    end
  end

  private

  def factor_breakdown
    weather = WeatherService.fetch(location.latitude, location.longitude, fallback_location: location)
    
    road_val = location.road_quality.to_s.downcase.strip
    road_penalty = ROAD_PENALTIES.fetch(road_val, 15)

    rain_val = weather[:rainfall_level].to_s.downcase.strip.presence || location.rainfall_level.to_s.downcase.strip
    rain_penalty = RAINFALL_PENALTIES.fetch(rain_val, 5)

    landslide_val = location.landslide_risk.to_s.downcase.strip
    landslide_penalty = LANDSLIDE_PENALTIES.fetch(landslide_val, 10)

    transport_val = location.transport_availability.to_s.downcase.strip
    transport_penalty = TRANSPORT_PENALTIES.fetch(transport_val, 10)

    hospital_dist = (location.distance_to_hospital || 15.0).to_f
    hospital_penalty = calculate_hospital_penalty(hospital_dist)

    warehouse_dist = (location.distance_to_warehouse || 25.0).to_f
    warehouse_penalty = calculate_warehouse_penalty(warehouse_dist)

    rainfall_display_value = if weather[:source] == "live" && weather[:temperature].present?
                               "#{rain_val.capitalize} (#{weather[:temperature].round(1)}°C, #{weather[:precipitation]} mm)"
                             else
                               rain_val.capitalize.presence || "Moderate"
                             end

    {
      road_quality: {
        title: "Road Quality",
        value: road_val.capitalize.presence || "Moderate",
        raw_value: road_val,
        impact: -road_penalty,
        impact_level: impact_level_text(road_penalty, 45),
        description: road_description(road_val)
      },
      rainfall: {
        title: "Rainfall & Weather",
        value: rainfall_display_value,
        raw_value: rain_val,
        impact: -rain_penalty,
        impact_level: impact_level_text(rain_penalty, 25),
        description: rainfall_description(rain_val, weather),
        weather: weather
      },
      landslide_risk: {
        title: "Landslide Risk",
        value: landslide_val.capitalize.presence || "Medium",
        raw_value: landslide_val,
        impact: -landslide_penalty,
        impact_level: impact_level_text(landslide_penalty, 40),
        description: landslide_description(landslide_val)
      },
      transport_availability: {
        title: "Transport Availability",
        value: transport_val.capitalize.presence || "Medium",
        raw_value: transport_val,
        impact: -transport_penalty,
        impact_level: impact_level_text(transport_penalty, 25),
        description: transport_description(transport_val)
      },
      distance_to_hospital: {
        title: "Distance to Hospital",
        value: "#{hospital_dist.round(1)} km",
        raw_value: hospital_dist,
        impact: -hospital_penalty,
        impact_level: impact_level_text(hospital_penalty, 20),
        description: hospital_description(hospital_dist)
      },
      distance_to_warehouse: {
        title: "Distance to Warehouse",
        value: "#{warehouse_dist.round(1)} km",
        raw_value: warehouse_dist,
        impact: -warehouse_penalty,
        impact_level: impact_level_text(warehouse_penalty, 20),
        description: warehouse_description(warehouse_dist)
      }
    }
  end

  def calculate_hospital_penalty(distance)
    if distance < 10.0
      0
    elsif distance <= 30.0
      5
    elsif distance <= 60.0
      10
    else
      20
    end
  end

  def calculate_warehouse_penalty(distance)
    if distance < 20.0
      0
    elsif distance <= 50.0
      5
    elsif distance <= 100.0
      10
    else
      20
    end
  end

  def impact_level_text(penalty, max_penalty)
    return "Optimal (No Penalty)" if penalty.zero?

    ratio = penalty.to_f / max_penalty
    if ratio >= 0.8
      "Critical Negative Impact"
    elsif ratio >= 0.5
      "High Negative Impact"
    elsif ratio >= 0.25
      "Moderate Negative Impact"
    else
      "Low Negative Impact"
    end
  end

  def identify_primary_risk_factor(factors)
    # Find factor with largest absolute impact penalty
    worst = factors.max_by { |_k, v| v[:impact].abs }
    return "Optimal Conditions" if worst.nil? || worst[1][:impact].zero?

    "#{worst[1][:title]} (#{worst[1][:value]} / #{worst[1][:impact]} pts)"
  end

  def road_description(val)
    case val
    when "excellent" then "Paved multi-lane highways with high load capacity"
    when "good"      then "Well-maintained asphalt roads with minor congestion"
    when "moderate"  then "Single-lane paved roads subject to seasonal wear"
    when "poor"      then "Unpaved/damaged roads with severe transit delays"
    when "critical"  then "Severely obstructed or broken routes; high vehicle breakdown risk"
    else "Standard regional road connectivity"
    end
  end

  def rainfall_description(val, weather = nil)
    base_text = case val
                when "low", "low rainfall"           then "Normal dry/mild precipitation"
                when "moderate", "moderate rainfall" then "Moderate seasonal monsoon showers"
                when "high", "high rainfall"         then "Heavy rainfall with localized flash flooding risks"
                when "extreme", "extreme rainfall"   then "Torrential cloudburst levels; severe waterlogging"
                else "Typical seasonal rainfall"
                end

    if weather && weather[:source] == "live"
      "Live Weather Telemetry: #{weather[:condition_text]} (#{weather[:temperature]&.round(1)}°C, Wind: #{weather[:wind_speed]&.round(1)} km/h, Rain: #{weather[:precipitation]} mm/hr). #{base_text}."
    else
      base_text
    end
  end

  def landslide_description(val)
    case val
    when "low"      then "Stable geological terrain; minimal slope failure risk"
    when "medium", "moderate" then "Moderate hilly terrain with occasional debris fall"
    when "high"     then "Steep vulnerable slopes prone to monsoon roadblocks"
    when "critical" then "Active fault zones with imminent major slope collapse hazard"
    else "Standard regional slope stability"
    end
  end

  def transport_description(val)
    case val
    when "high"   then "High density of commercial logistics and transport fleets"
    when "medium" then "Moderate availability of local transport carriers"
    when "low"    then "Scarce vehicle availability; limited specialized disaster transit"
    else "Standard transit fleet availability"
    end
  end

  def hospital_description(dist)
    if dist < 10.0
      "Immediate emergency medical care within reach (<10 km)"
    elsif dist <= 30.0
      "Secondary healthcare center accessible within standard emergency window (10-30 km)"
    elsif dist <= 60.0
      "Tertiary care facility distant; requires planned transit (30-60 km)"
    else
      "Extreme medical transit distance (>60 km); urgent airlift/mobile unit advised"
    end
  end

  def warehouse_description(dist)
    if dist < 20.0
      "Direct proximity to regional distribution hub (<20 km)"
    elsif dist <= 50.0
      "Accessible regional relief depot within standard supply radius (20-50 km)"
    elsif dist <= 100.0
      "Long-haul logistics transit required from supply hub (50-100 km)"
    else
      "Remote location beyond standard supply perimeter (>100 km); forward mini-depot recommended"
    end
  end
end
