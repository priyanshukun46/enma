class RouteAnalysis < ApplicationRecord
  belongs_to :origin, class_name: "Location", optional: true
  belongs_to :destination, class_name: "Location", optional: true

  serialize :all_routes_payload_json, coder: JSON
  serialize :segment_analysis_json, coder: JSON
  serialize :explainable_reasons_json, coder: JSON

  PRIORITY_MODES = %w[fastest safest balanced emergency].freeze

  validates :priority_mode, presence: true, inclusion: { in: PRIORITY_MODES }
  validates :vehicle_type, presence: true

  scope :recent, -> { order(analyzed_at: :desc) }
  scope :active, -> { where(status: "active") }
  scope :for_corridor, ->(orig_id, dest_id) { where(origin_id: orig_id, destination_id: dest_id) }

  def all_routes
    (all_routes_payload_json || {}).with_indifferent_access
  end

  def segment_analysis
    (segment_analysis_json || []).map(&:with_indifferent_access)
  end

  def explainable_reasons
    explainable_reasons_json || []
  end

  def formatted_distance
    "#{distance_km&.round(1) || 0} km"
  end

  def formatted_provider_eta
    format_minutes(provider_eta_minutes)
  end

  def formatted_enma_eta
    format_minutes(enma_adjusted_eta_minutes)
  end

  def delay_minutes
    return 0 if enma_adjusted_eta_minutes.nil? || provider_eta_minutes.nil?
    [enma_adjusted_eta_minutes - provider_eta_minutes, 0].max
  end

  def delay_formatted
    m = delay_minutes
    m > 0 ? "+#{m} mins delay" : "On schedule"
  end

  private

  def format_minutes(total_mins)
    return "—" if total_mins.nil?
    mins = total_mins.to_i
    h = mins / 60
    m = mins % 60
    if h > 0 && m > 0
      "#{h}h #{m}m"
    elsif h > 0
      "#{h}h"
    else
      "#{m}m"
    end
  end
end
