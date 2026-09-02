class LogisticsAlert < ApplicationRecord
  belongs_to :vehicle, optional: true
  belongs_to :shipment, optional: true

  serialize :metadata_json, coder: JSON

  ALERT_TYPES = %w[route_deviation delivery_delay high_risk_corridor blocked_route incident_ahead severe_weather vehicle_offline].freeze
  SEVERITIES = %w[info warning high critical].freeze
  STATUSES = %w[active acknowledged resolved].freeze

  validates :alert_type, presence: true, inclusion: { in: ALERT_TYPES }
  validates :severity, presence: true, inclusion: { in: SEVERITIES }
  validates :title, presence: true
  validates :message, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :active, -> { where(status: "active") }
  scope :recent, -> { order(created_at: :desc) }
  scope :critical_or_high, -> { where(severity: %w[critical high]) }

  def severity_badge_class
    case severity
    when "critical"
      "bg-red-100 dark:bg-red-950 text-red-800 dark:text-red-300 border-red-300 dark:border-red-800 animate-pulse"
    when "high"
      "bg-rose-100 dark:bg-rose-950 text-rose-800 dark:text-rose-300 border-rose-300 dark:border-rose-800"
    when "warning"
      "bg-amber-100 dark:bg-amber-950 text-amber-800 dark:text-amber-300 border-amber-300 dark:border-amber-800"
    else
      "bg-blue-100 dark:bg-blue-950 text-blue-800 dark:text-blue-300 border-blue-300 dark:border-blue-800"
    end
  end

  def icon_class
    case alert_type
    when "route_deviation"
      "fa-route"
    when "delivery_delay"
      "fa-clock"
    when "high_risk_corridor"
      "fa-triangle-exclamation"
    when "blocked_route"
      "fa-road-barrier"
    when "incident_ahead"
      "fa-land-mine-on"
    when "severe_weather"
      "fa-cloud-bolt"
    else
      "fa-bell"
    end
  end
end
