class LogisticsRoute < ApplicationRecord
  belongs_to :origin, class_name: "Location"
  belongs_to :destination, class_name: "Location"

  validates :origin_id, presence: true
  validates :destination_id, presence: true
  validates :vehicle_type, presence: true
  validates :distance, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :estimated_time, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :risk_score, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :route_type, presence: true, inclusion: { in: %w[fastest safest efficient balanced alternate] }

  validate :origin_and_destination_must_differ

  scope :recent, -> { order(created_at: :desc).limit(5) }
  scope :recommended, -> { where(recommended: true) }

  def risk_level
    if risk_score <= 25.0
      "LOW"
    elsif risk_score <= 50.0
      "MODERATE"
    elsif risk_score <= 75.0
      "HIGH"
    else
      "CRITICAL"
    end
  end

  def formatted_time
    hours = estimated_time.to_f
    h = hours.floor
    m = ((hours - h) * 60).round
    if h > 0 && m > 0
      "#{h}h #{m}m"
    elsif h > 0
      "#{h}h"
    else
      "#{m}m"
    end
  end

  def route_type_display
    case route_type
    when "fastest" then "Fastest Route"
    when "safest" then "Safest Route"
    when "efficient" then "Most Efficient Route"
    else route_type.to_s.titleize
    end
  end

  private

  def origin_and_destination_must_differ
    if origin_id.present? && destination_id.present? && origin_id == destination_id
      errors.add(:destination_id, "cannot be the same as origin location")
    end
  end
end
