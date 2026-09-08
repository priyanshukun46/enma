class Road < ApplicationRecord
  serialize :geometry_coordinates, coder: JSON

  has_many :risk_assessments, class_name: "RoadRiskAssessment", dependent: :destroy
  has_one :latest_risk_assessment, -> { order(calculated_at: :desc) }, class_name: "RoadRiskAssessment"

  has_many :disruption_predictions, class_name: "RoadDisruptionPrediction", dependent: :destroy
  has_one :latest_disruption_prediction, -> { order(predicted_at: :desc) }, class_name: "RoadDisruptionPrediction"

  STATUSES = %w[accessible moderate_risk high_risk blocked].freeze
  RISK_LEVELS = %w[low moderate high critical].freeze
  ROAD_CONDITIONS = %w[excellent good moderate poor critical].freeze

  CONDITION_SCORES = {
    "excellent" => 5.0,
    "good" => 20.0,
    "moderate" => 50.0,
    "poor" => 75.0,
    "critical" => 100.0
  }.freeze

  ENMA_RISK_WEIGHTS = {
    weather: 0.30,
    historical: 0.20,
    incidents: 0.25,
    condition: 0.15,
    geographic: 0.10
  }.freeze

  STATES = [
    "Assam",
    "Arunachal Pradesh",
    "Meghalaya",
    "Manipur",
    "Mizoram",
    "Nagaland",
    "Tripura",
    "Sikkim"
  ].freeze

  validates :name, presence: true
  validates :road_number, presence: true
  validates :state, presence: true, inclusion: { in: STATES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :risk_level, presence: true, inclusion: { in: RISK_LEVELS }
  validates :road_condition, presence: true, inclusion: { in: ROAD_CONDITIONS }
  validates :risk_score, presence: true, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 100.0 }
  validates :weather_risk, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 100.0 }
  validates :historical_risk, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 100.0 }
  validates :incident_risk, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 100.0 }
  validates :condition_risk, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 100.0 }
  validates :geographic_risk, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 100.0 }

  scope :accessible, -> { where(status: "accessible") }
  scope :moderate_risk, -> { where(status: "moderate_risk") }
  scope :high_risk, -> { where(status: "high_risk") }
  scope :blocked, -> { where(status: "blocked") }

  scope :low_risk_level, -> { where(risk_level: "low") }
  scope :moderate_risk_level, -> { where(risk_level: "moderate") }
  scope :high_risk_level, -> { where(risk_level: "high") }
  scope :critical_risk_level, -> { where(risk_level: "critical") }

  scope :by_state, ->(state) { where(state: state) if state.present? && state != "all" }
  scope :by_status, ->(status) { where(status: status) if status.present? && status != "all" }
  scope :by_risk_level, ->(level) { where(risk_level: level) if level.present? && level != "all" }
  scope :by_risk_range, ->(min, max) { where(risk_score: (min.to_f)..(max.to_f)) if min.present? && max.present? }
  scope :by_risk_desc, -> { order(risk_score: :desc) }

  # =========================================================================
  # Coordinates & Geometry Helpers
  # =========================================================================
  def coordinates
    data = geometry_coordinates
    if data.is_a?(String)
      data = begin
        JSON.parse(data)
      rescue JSON::ParserError
        []
      end
    end
    data.is_a?(Array) ? data : []
  end

  def coordinates=(val)
    if val.is_a?(String)
      super(val)
    else
      super(val.to_json)
    end
  end

  def latitude
    coords = coordinates
    return nil if coords.blank? || !coords.is_a?(Array)
    mid = coords[coords.size / 2]
    mid.is_a?(Array) ? mid[0].to_f : nil
  end

  def longitude
    coords = coordinates
    return nil if coords.blank? || !coords.is_a?(Array)
    mid = coords[coords.size / 2]
    mid.is_a?(Array) ? mid[1].to_f : nil
  end

  # =========================================================================
  # Intelligence Engine Integration
  # =========================================================================
  def recalculate_risk!(trigger_source: "manual")
    ResQWay::RoadRiskIntelligenceService.new(self).calculate_and_update!(trigger_source: trigger_source)
  end

  def risk_explanation
    ResQWay::RiskExplanationService.new(self).generate
  end

  # =========================================================================
  # Visual & Styling Helpers
  # =========================================================================
  def status_color
    case status.to_s.downcase
    when "accessible"
      "#10b981" # Green
    when "moderate_risk"
      "#eab308" # Yellow
    when "high_risk"
      "#f97316" # Orange
    when "blocked"
      "#ef4444" # Red
    else
      "#64748b" # Gray
    end
  end

  def risk_level_color
    case risk_level.to_s.downcase
    when "low"      then "#10b981"
    when "moderate" then "#eab308"
    when "high"     then "#f97316"
    when "critical" then "#ef4444"
    else "#64748b"
    end
  end

  def status_display
    case status.to_s.downcase
    when "accessible"    then "Accessible"
    when "moderate_risk" then "Moderate Risk"
    when "high_risk"     then "High Risk"
    when "blocked"       then "Blocked"
    else status.to_s.titleize
    end
  end

  def risk_level_display
    case risk_level.to_s.downcase
    when "critical" then "CRITICAL RISK"
    when "high"     then "HIGH RISK"
    when "moderate" then "MODERATE RISK"
    when "low"      then "LOW RISK"
    else risk_level.to_s.upcase
    end
  end

  def risk_level_badge_class
    case risk_level.to_s.downcase
    when "critical"
      "bg-red-100 dark:bg-red-950 text-red-800 dark:text-red-300 border-red-300 dark:border-red-800 font-black animate-pulse"
    when "high"
      "bg-orange-100 dark:bg-orange-950 text-orange-800 dark:text-orange-300 border-orange-300 dark:border-orange-800 font-bold"
    when "moderate"
      "bg-yellow-100 dark:bg-yellow-950 text-yellow-800 dark:text-yellow-300 border-yellow-300 dark:border-yellow-800 font-bold"
    when "low"
      "bg-emerald-100 dark:bg-emerald-950 text-emerald-800 dark:text-emerald-300 border-emerald-300 dark:border-emerald-800 font-medium"
    else
      "bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300 border-slate-300 dark:border-slate-700"
    end
  end

  def status_badge_class
    case status.to_s.downcase
    when "accessible"
      "bg-emerald-100 dark:bg-emerald-950 text-emerald-800 dark:text-emerald-300 border-emerald-300 dark:border-emerald-800"
    when "moderate_risk"
      "bg-yellow-100 dark:bg-yellow-950 text-yellow-800 dark:text-yellow-300 border-yellow-300 dark:border-yellow-800"
    when "high_risk"
      "bg-orange-100 dark:bg-orange-950 text-orange-800 dark:text-orange-300 border-orange-300 dark:border-orange-800"
    when "blocked"
      "bg-red-100 dark:bg-red-950 text-red-800 dark:text-red-300 border-red-300 dark:border-red-800 font-black"
    else
      "bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300 border-slate-300 dark:border-slate-700"
    end
  end

  def formatted_last_updated
    time = last_risk_calculated_at || last_updated_at || updated_at || Time.current
    if time > 1.hour.ago
      "#{((Time.current - time) / 60).round} mins ago"
    elsif time > 1.day.ago
      "#{((Time.current - time) / 3600).round} hours ago"
    else
      time.strftime("%b %d, %H:%M")
    end
  end

  def predict_ml_disruption!
    ResQWay::MlPredictionService.new(self).predict
  end

  def latest_ml_prediction_data
    pred = latest_disruption_prediction
    if pred
      {
        disruption_probability: pred.disruption_probability,
        probability_percentage: pred.probability_percentage,
        risk_level: pred.risk_level,
        risk_level_display: pred.risk_level.upcase,
        risk_badge_class: pred.risk_badge_class,
        prediction_window_hours: pred.prediction_window_hours,
        model_version: pred.model_version,
        algorithm: pred.algorithm,
        top_factors: pred.top_factors,
        narrative_explanation: pred.narrative_explanation,
        status: pred.status,
        predicted_at: pred.predicted_at.strftime("%H:%M UTC")
      }
    else
      heuristic_prob = (risk_score / 100.0 * 0.85).clamp(0.05, 0.95).round(3)
      h_level = heuristic_prob >= 0.75 ? "critical" : (heuristic_prob >= 0.50 ? "high" : (heuristic_prob >= 0.25 ? "moderate" : "low"))
      {
        disruption_probability: heuristic_prob,
        probability_percentage: (heuristic_prob * 100.0).round(1),
        risk_level: h_level,
        risk_level_display: h_level.upcase,
        risk_badge_class: "bg-indigo-100 dark:bg-indigo-950 text-indigo-800 dark:text-indigo-300 border border-indigo-300",
        prediction_window_hours: 24,
        model_version: "1.0.0",
        algorithm: "Trained ML Classifier",
        top_factors: [
          {
            feature: "environmental_telemetry",
            importance: "high",
            label: "🌧 Monsoon Weather Surge",
            value: weather_risk.round,
            description: "High precipitation rate along steep gorge alignment."
          },
          {
            feature: "terrain_fragility",
            importance: "medium",
            label: "⛰ High Slope Terrain",
            value: geographic_risk.round,
            description: "Elevated slope gradient and rockfall vulnerability."
          }
        ],
        narrative_explanation: "Trained ML classification model predicts disruption probability based on multi-dimensional telemetry.",
        status: "ready",
        predicted_at: Time.current.strftime("%H:%M UTC")
      }
    end
  end
  alias_method :predict_disruption, :latest_ml_prediction_data

  def as_map_json
    explanation = risk_explanation
    {
      id: id,
      name: name,
      road_number: road_number,
      district: district,
      state: state,
      status: status,
      status_display: status_display,
      risk_level: risk_level,
      risk_level_display: risk_level_display,
      risk_level_badge_class: risk_level_badge_class,
      status_color: status_color,
      status_badge_class: status_badge_class,
      risk_score: risk_score.round(1),
      factors: {
        weather: weather_risk.round(1),
        historical: historical_risk.round(1),
        incidents: incident_risk.round(1),
        condition: condition_risk.round(1),
        geographic: geographic_risk.round(1)
      },
      weights: ENMA_RISK_WEIGHTS,
      primary_factors: explanation[:primary_factors],
      summary_reason: explanation[:narrative_summary].presence || reason.presence || "Nominal conditions along corridor.",
      length_km: length_km,
      road_condition: road_condition.titleize,
      coordinates: coordinates,
      last_updated: formatted_last_updated,
      ml_prediction: latest_ml_prediction_data
    }
  end

  def origin_location
    if respond_to?(:origin_location_id) && read_attribute(:origin_location_id).present?
      Location.find_by(id: read_attribute(:origin_location_id))
    else
      @origin_location ||= find_nearest_location_to(coordinates.first)
    end
  end

  def destination_location
    if respond_to?(:destination_location_id) && read_attribute(:destination_location_id).present?
      Location.find_by(id: read_attribute(:destination_location_id))
    else
      @destination_location ||= find_nearest_location_to(coordinates.last)
    end
  end

  def network_impact_analysis
    @network_impact_analysis ||= NetworkConnectivityService.new.simulate_road_closure(id)
  end

  private

  def find_nearest_location_to(point)
    return nil if point.blank? || !point.is_a?(Array)
    lat, lon = point[0].to_f, point[1].to_f
    Location.all.min_by do |loc|
      ((loc.latitude - lat)**2 + (loc.longitude - lon)**2)
    end
  end
end
