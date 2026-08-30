class AccessibilityRecommendationService
  attr_reader :location, :score, :factors

  def initialize(location, score_data = nil)
    @location = location
    score_data ||= AccessibilityScoreService.new(location).calculate
    @score = score_data[:score]
    @factors = score_data[:factors]
  end

  def generate
    recommendations = []

    # Score-tier baseline recommendations
    if score < 40.0
      recommendations << {
        priority: "Critical",
        badge_class: "bg-red-100 text-red-800 border-red-200",
        action: "Pre-position Emergency Supplies",
        detail: "Stock critical relief essentials (rations, potable water, medical kits) at local decentralized shelters before severe weather events."
      }
      recommendations << {
        priority: "Critical",
        badge_class: "bg-red-100 text-red-800 border-red-200",
        action: "Deploy Emergency Response Teams on Standby",
        detail: "Position SDRF/NDRF rapid-response personnel and specialized clearance heavy machinery on high readiness."
      }
      recommendations << {
        priority: "High",
        badge_class: "bg-orange-100 text-orange-800 border-orange-200",
        action: "Identify Alternative Transport Routes",
        detail: "Map secondary feeder trails, helipad coordinates, and riverways for redundant evacuation routes in case primary corridors fail."
      }
      recommendations << {
        priority: "High",
        badge_class: "bg-orange-100 text-orange-800 border-orange-200",
        action: "Continuous Road & Weather Monitoring",
        detail: "Integrate automated satellite/gauge telemetry for live hazard notifications and early evacuation triggers."
      }
    elsif score < 60.0
      recommendations << {
        priority: "High",
        badge_class: "bg-orange-100 text-orange-800 border-orange-200",
        action: "Improve Logistics Connectivity",
        detail: "Upgrade vulnerable road bottlenecks, bridges, and culverts to handle medium-to-heavy supply vehicles."
      }
      recommendations << {
        priority: "Medium",
        badge_class: "bg-yellow-100 text-yellow-800 border-yellow-200",
        action: "Maintain Backup Transport Fleet",
        detail: "Contract local 4x4 and high-clearance transport providers for emergency dispatch during seasonal monsoon disruptions."
      }
      recommendations << {
        priority: "Medium",
        badge_class: "bg-yellow-100 text-yellow-800 border-yellow-200",
        action: "Monitor Weather & Rainfall Conditions",
        detail: "Track regional meteorological warnings to schedule pre-disaster replenishment shipments ahead of major storms."
      }
    elsif score < 80.0
      recommendations << {
        priority: "Medium",
        badge_class: "bg-blue-100 text-blue-800 border-blue-200",
        action: "Maintain Logistics Infrastructure",
        detail: "Ensure seasonal maintenance of main highway access ways and clear roadside drainage channels."
      }
      recommendations << {
        priority: "Low",
        badge_class: "bg-gray-100 text-gray-800 border-gray-200",
        action: "Periodic Accessibility Audits",
        detail: "Perform quarterly checks on route clearance, bridge load limits, and communication towers."
      }
    else
      recommendations << {
        priority: "Low",
        badge_class: "bg-green-100 text-green-800 border-green-200",
        action: "Normal Monitoring & Optimal Dispatch",
        detail: "Maintain standard inventory levels and regular dispatch protocols from regional distribution centers."
      }
      recommendations << {
        priority: "Low",
        badge_class: "bg-green-100 text-green-800 border-green-200",
        action: "Regional Hub Coordination",
        detail: "Serve as a staging and relay point to support adjacent high-risk and difficult-access communities."
      }
    end

    # Specific factor-based recommendations
    add_factor_specific_recommendations(recommendations)

    recommendations
  end

  private

  def add_factor_specific_recommendations(recs)
    landslide = location.landslide_risk.to_s.downcase
    if %w[high critical].include?(landslide)
      recs << {
        priority: "High",
        badge_class: "bg-red-100 text-red-800 border-red-200",
        action: "Slope Stabilization & Early Warning Sensors",
        detail: "Deploy geotechnical tilt sensors and rockfall netting on critical hill cuts along primary access roads."
      }
    end

    rainfall = location.rainfall_level.to_s.downcase
    if %w[high extreme].include?(rainfall)
      recs << {
        priority: "High",
        badge_class: "bg-blue-100 text-blue-800 border-blue-200",
        action: "Flood Drainage & Waterway Clearing",
        detail: "Clear culvert debris and prepare water pump systems to mitigate roadway inundation during cloudbursts."
      }
    end

    road = location.road_quality.to_s.downcase
    if %w[poor critical].include?(road)
      recs << {
        priority: "Critical",
        badge_class: "bg-red-100 text-red-800 border-red-200",
        action: "Urgent Pavement & Corridor Restoration",
        detail: "Coordinate with Border Roads Organisation (BRO) and State PWD for prioritized resurfacing and bypass construction."
      }
    end

    transport = location.transport_availability.to_s.downcase
    if transport == "low"
      recs << {
        priority: "Medium",
        badge_class: "bg-yellow-100 text-yellow-800 border-yellow-200",
        action: "Mobilize Regional Logistics Fleet Partners",
        detail: "Establish standing agreements with local transport unions to guarantee dedicated vehicle allocation in emergencies."
      }
    end

    hosp_dist = (location.distance_to_hospital || 0).to_f
    if hosp_dist > 50.0
      recs << {
        priority: "High",
        badge_class: "bg-red-100 text-red-800 border-red-200",
        action: "Medical Airlift / Mobile Clinic Pre-positioning",
        detail: "Distance to emergency healthcare is #{hosp_dist.round(1)} km. Establish telemedicine connectivity and air-ambulance landing clearance."
      }
    end

    wh_dist = (location.distance_to_warehouse || 0).to_f
    if wh_dist > 80.0
      recs << {
        priority: "Medium",
        badge_class: "bg-orange-100 text-orange-800 border-orange-200",
        action: "Establish Forward Mini-Depot",
        detail: "Distance to nearest central warehouse is #{wh_dist.round(1)} km. Deploy forward buffer storage to reduce supply lead-time."
      }
    end
  end
end
