class ResponsePlan < ApplicationRecord
  belongs_to :emergency

  validates :status, presence: true

  serialize :primary_risks, coder: JSON
  serialize :action_items, coder: JSON
  serialize :plan_payload, coder: JSON

  scope :recent, -> { order(created_at: :desc) }
  scope :active, -> { where(status: "active") }

  def formatted_briefing
    <<~BRIEFING
      ================================================================================
      ResQWay INTELLIGENT DISASTER RESPONSE BRIEFING
      ================================================================================
      Incident: #{emergency.title}
      Type: #{emergency.emergency_type} | Threat Level: #{severity_level} (Score: #{severity_score}/100)
      Coordinates: #{emergency.latitude.round(4)}°N, #{emergency.longitude.round(4)}°E (Radius: #{emergency.affected_radius} km)
      Generated: #{generated_at&.strftime("%Y-%m-%d %H:%M:%S UTC") || created_at.strftime("%Y-%m-%d %H:%M:%S UTC")}
      Status: #{status.upcase}

      --------------------------------------------------------------------------------
      1. POPULATION & COMMUNITY IMPACT
      --------------------------------------------------------------------------------
      Total Affected Communities: #{affected_communities_count}
      Total Population at Risk: #{total_population_at_risk.to_fs(:delimited)} Civilians

      --------------------------------------------------------------------------------
      2. STRATEGIC RELIEF ALLOCATION
      --------------------------------------------------------------------------------
      Designated Warehouse: #{warehouse_name}
      Optimal Dispatch Route: #{route_title}
      Estimated Response ETA: #{estimated_response_time}

      --------------------------------------------------------------------------------
      3. PRIMARY RISKS IDENTIFIED
      --------------------------------------------------------------------------------
      #{Array(primary_risks).map { |r| "• #{r}" }.join("\n")}

      --------------------------------------------------------------------------------
      4. TACTICAL ACTION DIRECTIVES
      --------------------------------------------------------------------------------
      #{Array(action_items).map { |a| a.is_a?(Hash) ? "• [#{a['priority']}] #{a['action']}: #{a['detail']}" : "• #{a}" }.join("\n")}

      ================================================================================
      ResQWay Intelligence Platform — Decision Support System
      ================================================================================
    BRIEFING
  end
end
