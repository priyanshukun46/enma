module ResQWay
  class EtaIntelligenceService
    DEFAULT_SPEED_KMH = 45.0

    attr_reader :shipment, :current_speed, :remaining_distance_km, :corridor_risk, :ml_disruption_prob, :incident_count

    def initialize(shipment:, current_speed: nil, remaining_distance_km: nil, corridor_risk: 0.0, ml_disruption_prob: 0.0, incident_count: 0)
      @shipment = shipment
      @current_speed = (current_speed.to_f > 5.0) ? current_speed.to_f : DEFAULT_SPEED_KMH
      @remaining_distance_km = remaining_distance_km.to_f
      @corridor_risk = corridor_risk.to_f
      @ml_disruption_prob = ml_disruption_prob.to_f
      @incident_count = incident_count.to_i
    end

    def calculate
      # 1. Base transit time remaining in minutes
      effective_speed = [current_speed, 15.0].max
      base_remaining_hours = remaining_distance_km / effective_speed
      base_remaining_mins = (base_remaining_hours * 60).round

      now = Time.current
      current_estimated_eta = now + base_remaining_mins.minutes

      # 2. Risk-Driven Delay Calculation (Weather, Active Incidents, Road Degradation, ML)
      delay_mins = 0
      delay_mins += 15 if corridor_risk >= 50.0
      delay_mins += 25 if corridor_risk >= 75.0
      delay_mins += (incident_count * 20)
      delay_mins += (ml_disruption_prob * 30).round if ml_disruption_prob >= 0.40

      enma_adjusted_eta = current_estimated_eta + delay_mins.minutes

      # Planned ETA (preserve initial provider target or fallback)
      provider_planned_eta = shipment.provider_planned_eta || (now + ((shipment.total_distance_km.to_f / DEFAULT_SPEED_KMH) * 60).round.minutes)

      # Total delivery delay from original plan
      total_delay_from_plan = [((enma_adjusted_eta - provider_planned_eta) / 60.0).round, 0].max

      {
        provider_planned_eta: provider_planned_eta,
        current_estimated_eta: current_estimated_eta,
        enma_adjusted_eta: enma_adjusted_eta,
        delay_minutes: total_delay_from_plan,
        risk_delay_added_minutes: delay_mins,
        remaining_minutes: base_remaining_mins + delay_mins,
        formatted_enma_eta: enma_adjusted_eta.strftime("%l:%M %p"),
        formatted_planned_eta: provider_planned_eta.strftime("%l:%M %p"),
        delay_badge: total_delay_from_plan > 0 ? "+#{total_delay_from_plan} min delay" : "On schedule"
      }
    end
  end
end
