module ResQWay
  class RiskExplanationService
    attr_reader :road

    def initialize(road)
      @road = road
    end

    def generate
      primary_factors = []
      narrative_parts = []

      # 1. Evaluate Recent Incident Risk
      if road.incident_risk.to_f >= 70.0
        primary_factors << {
          icon: "🪨",
          label: "Incident Risk",
          score: road.incident_risk.round(0),
          text: "Critical field incident / blockage active in close proximity to corridor."
        }
        narrative_parts << "recent severe field hazard reports"
      elsif road.incident_risk.to_f >= 40.0
        primary_factors << {
          icon: "⚠️",
          label: "Incident Risk",
          score: road.incident_risk.round(0),
          text: "Moderate transportation hazard or vehicle stall reported along route."
        }
        narrative_parts << "active field disruptions"
      end

      # 2. Evaluate Weather Risk
      if road.weather_risk.to_f >= 60.0
        primary_factors << {
          icon: "🌧",
          label: "Weather Risk",
          score: road.weather_risk.round(0),
          text: "Heavy precipitation and hydro-meteorological surge detected across regional sector."
        }
        narrative_parts << "adverse monsoon weather conditions"
      elsif road.weather_risk.to_f >= 40.0
        primary_factors << {
          icon: "☁️",
          label: "Weather Risk",
          score: road.weather_risk.round(0),
          text: "Intermittent rainfall and reduced optical visibility along route."
        }
      end

      # 3. Evaluate Geographic & Terrain Risk
      if road.geographic_risk.to_f >= 70.0
        primary_factors << {
          icon: "⛰",
          label: "Geographic Risk",
          score: road.geographic_risk.round(0),
          text: "Steep mountain gorge alignment with elevated landslide vulnerability."
        }
        narrative_parts << "high-slope terrain vulnerability"
      elsif road.geographic_risk.to_f >= 50.0
        primary_factors << {
          icon: "🌲",
          label: "Geographic Risk",
          score: road.geographic_risk.round(0),
          text: "Hilly transit corridor with winding switchbacks."
        }
      end

      # 4. Evaluate Road Condition
      if road.condition_risk.to_f >= 70.0
        primary_factors << {
          icon: "🚧",
          label: "Road Condition",
          score: road.condition_risk.round(0),
          text: "Pavement degradation, single-lane pinch point, or culvert damage."
        }
        narrative_parts << "degraded asphalt structural integrity"
      end

      # 5. Evaluate Historical Risk
      if road.historical_risk.to_f >= 70.0
        primary_factors << {
          icon: "📜",
          label: "Historical Vulnerability",
          score: road.historical_risk.round(0),
          text: "Historical disaster corridor subject to frequent seasonal cut-offs."
        }
      end

      # Fallback if no specific high risk factor
      if primary_factors.empty?
        primary_factors << {
          icon: "✅",
          label: "Nominal Operating Status",
          score: road.risk_score.round(0),
          text: "Standard road conditions with normal logistics transit velocities."
        }
      end

      # Construct narrative synthesis
      summary = if narrative_parts.any?
                  "Risk elevated to #{road.risk_level.upcase} due to #{narrative_parts.to_sentence}."
                else
                  "Corridor operating within nominal safety parameters."
                end

      {
        road_id: road.id,
        road_number: road.road_number,
        risk_score: road.risk_score.round(1),
        risk_level: road.risk_level,
        primary_factors: primary_factors,
        narrative_summary: summary
      }
    end
  end
end
