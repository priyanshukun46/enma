class Shipment < ApplicationRecord
  belongs_to :vehicle, optional: true
  belongs_to :origin, class_name: "Location", optional: true
  belongs_to :destination, class_name: "Location", optional: true
  belongs_to :route_analysis, optional: true
  has_many :vehicle_locations, dependent: :nullify
  has_many :logistics_alerts, dependent: :destroy

  serialize :planned_route_geometry_json, coder: JSON
  serialize :active_rerouting_recommendation_json, coder: JSON

  STATUSES = %w[planned assigned in_transit delayed rerouting delivered cancelled].freeze
  CARGO_TYPES = %w[medicine food agriculture construction emergency_relief other].freeze
  PRIORITIES = %w[normal high critical emergency].freeze

  CARGO_METADATA = {
    "medicine" => { label: "Medicines & Vaccines", icon: "fa-kit-medical", color: "text-rose-600 dark:text-rose-400" },
    "food" => { label: "Food & Grain Relief", icon: "fa-bowl-rice", color: "text-amber-600 dark:text-amber-400" },
    "agriculture" => { label: "Agricultural Produce", icon: "fa-wheat-awn", color: "text-emerald-600 dark:text-emerald-400" },
    "construction" => { label: "Construction Materials", icon: "fa-trowel-bricks", color: "text-slate-600 dark:text-slate-400" },
    "emergency_relief" => { label: "Disaster Relief Kits", icon: "fa-life-ring", color: "text-indigo-600 dark:text-indigo-400" },
    "other" => { label: "General Logistics Cargo", icon: "fa-boxes-stacked", color: "text-slate-500 dark:text-slate-400" }
  }.freeze

  validates :tracking_number, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :cargo_type, presence: true, inclusion: { in: CARGO_TYPES }
  validates :priority, presence: true, inclusion: { in: PRIORITIES }

  before_validation :ensure_tracking_number, on: :create

  scope :active, -> { where(status: %w[planned assigned in_transit delayed rerouting]) }
  scope :in_transit, -> { where(status: "in_transit") }
  scope :delayed, -> { where(status: "delayed") }
  scope :delivered, -> { where(status: "delivered") }
  scope :recent, -> { order(created_at: :desc) }

  def planned_geometry
    planned_route_geometry_json || []
  end

  def rerouting_recommendation
    active_rerouting_recommendation_json || {}
  end

  def formatted_delay
    return "On Schedule" if delay_minutes.nil? || delay_minutes <= 0
    "+#{delay_minutes} min delay"
  end

  def cargo_meta
    CARGO_METADATA[cargo_type] || CARGO_METADATA["other"]
  end

  def priority_badge_class
    case priority
    when "emergency"
      "bg-red-100 dark:bg-red-950 text-red-800 dark:text-red-300 border-red-300 dark:border-red-800 animate-pulse"
    when "critical"
      "bg-rose-100 dark:bg-rose-950 text-rose-800 dark:text-rose-300 border-rose-300 dark:border-rose-800"
    when "high"
      "bg-amber-100 dark:bg-amber-950 text-amber-800 dark:text-amber-300 border-amber-300 dark:border-amber-800"
    else
      "bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300 border-slate-200 dark:border-slate-700"
    end
  end

  def status_badge_class
    case status
    when "in_transit"
      "bg-blue-100 dark:bg-blue-950 text-blue-800 dark:text-blue-300 border-blue-300 dark:border-blue-800"
    when "delayed"
      "bg-amber-100 dark:bg-amber-950 text-amber-800 dark:text-amber-300 border-amber-300 dark:border-amber-800"
    when "rerouting"
      "bg-purple-100 dark:bg-purple-950 text-purple-800 dark:text-purple-300 border-purple-300 dark:border-purple-800"
    when "delivered"
      "bg-emerald-100 dark:bg-emerald-950 text-emerald-800 dark:text-emerald-300 border-emerald-300 dark:border-emerald-800"
    when "assigned"
      "bg-indigo-100 dark:bg-indigo-950 text-indigo-800 dark:text-indigo-300 border-indigo-300 dark:border-indigo-800"
    else
      "bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300"
    end
  end

  private

  def ensure_tracking_number
    self.tracking_number ||= "ENMA-TRK-#{Time.current.strftime('%Y%m%d')}-#{SecureRandom.alphanumeric(6).upcase}"
  end
end
