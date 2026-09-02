class Vehicle < ApplicationRecord
  has_many :vehicle_locations, dependent: :destroy
  has_many :shipments, dependent: :nullify
  has_many :logistics_alerts, dependent: :destroy

  has_one :active_shipment, -> { where(status: %w[in_transit assigned rerouting delayed]) }, class_name: "Shipment"

  serialize :metadata_json, coder: JSON

  STATUSES = %w[available assigned in_transit delayed stopped completed inactive].freeze
  VEHICLE_TYPES = ["Truck", "Ambulance", "Emergency Vehicle", "Supply Vehicle", "Light Transport", "Heavy Logistics Truck"].freeze

  validates :registration_number, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :vehicle_type, presence: true

  before_validation :generate_api_token, on: :create

  scope :active, -> { where.not(status: "inactive") }
  scope :in_transit, -> { where(status: "in_transit") }
  scope :available, -> { where(status: "available") }
  scope :delayed, -> { where(status: "delayed") }

  def current_position
    return nil if current_latitude.blank? || current_longitude.blank?
    [current_latitude, current_longitude]
  end

  def coordinates
    current_position
  end

  def metadata
    metadata_json || {}
  end

  def status_badge_class
    case status
    when "available"
      "bg-emerald-100 dark:bg-emerald-950 text-emerald-800 dark:text-emerald-300 border-emerald-300 dark:border-emerald-800"
    when "in_transit"
      "bg-blue-100 dark:bg-blue-950 text-blue-800 dark:text-blue-300 border-blue-300 dark:border-blue-800"
    when "assigned"
      "bg-indigo-100 dark:bg-indigo-950 text-indigo-800 dark:text-indigo-300 border-indigo-300 dark:border-indigo-800"
    when "delayed"
      "bg-amber-100 dark:bg-amber-950 text-amber-800 dark:text-amber-300 border-amber-300 dark:border-amber-800"
    when "stopped"
      "bg-purple-100 dark:bg-purple-950 text-purple-800 dark:text-purple-300 border-purple-300 dark:border-purple-800"
    when "completed"
      "bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300 border-slate-300 dark:border-slate-700"
    else
      "bg-slate-200 dark:bg-slate-800 text-slate-600 dark:text-slate-400"
    end
  end

  def update_position_from_gps!(lat, lon, speed: 0.0, heading: 0.0, recorded_at: Time.current)
    update_columns(
      current_latitude: lat.to_f.round(6),
      current_longitude: lon.to_f.round(6),
      current_speed: speed.to_f.round(1),
      current_heading: heading.to_f.round(1),
      last_location_at: recorded_at
    )
  end

  private

  def generate_api_token
    self.api_auth_token ||= "v_key_#{SecureRandom.hex(16)}"
  end
end
