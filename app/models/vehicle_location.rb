class VehicleLocation < ApplicationRecord
  belongs_to :vehicle
  belongs_to :shipment, optional: true

  serialize :raw_payload_json, coder: JSON

  SOURCES = %w[mobile gps_device simulation manual].freeze

  validates :latitude, presence: true, numericality: { greater_than_or_equal_to: -90.0, less_than_or_equal_to: 90.0 }
  validates :longitude, presence: true, numericality: { greater_than_or_equal_to: -180.0, less_than_or_equal_to: 180.0 }
  validates :recorded_at, presence: true
  validates :source, presence: true, inclusion: { in: SOURCES }

  scope :recent, -> { order(recorded_at: :desc) }
  scope :chronological, -> { order(recorded_at: :asc) }
  scope :for_vehicle, ->(vid) { where(vehicle_id: vid) }

  def coordinates
    [latitude, longitude]
  end
end
