class Emergency < ApplicationRecord
  belongs_to :location, optional: true

  validates :title, presence: true
  validates :emergency_type, presence: true
  validates :severity, presence: true
  validates :latitude, presence: true, numericality: true
  validates :longitude, presence: true, numericality: true
  validates :status, presence: true
  validates :affected_radius, presence: true, numericality: { greater_than: 0 }

  scope :active_or_responding, -> { where(status: ["Active", "Responding", "Monitoring", "open"]) }
  scope :active, -> { where(status: "Active") }
  scope :monitoring, -> { where(status: "Monitoring") }
  scope :responding, -> { where(status: "Responding") }
  scope :resolved, -> { where(status: "Resolved") }
  scope :critical, -> { where(severity: ["Critical", "critical"]) }
  scope :recent, -> { order(created_at: :desc) }

  def active?
    %w[Active Responding Monitoring open].include?(status)
  end

  def resolved?
    status == "Resolved"
  end

  def response_analysis
    EmergencyResponseService.new(self).analyze
  end

  def severity_badge_class
    case severity.to_s.downcase
    when "critical" then "bg-red-100 text-red-800 border-red-300 font-bold"
    when "high"     then "bg-orange-100 text-orange-800 border-orange-300 font-semibold"
    when "medium"   then "bg-yellow-100 text-yellow-800 border-yellow-300 font-medium"
    when "low"      then "bg-green-100 text-green-800 border-green-300 font-medium"
    else "bg-gray-100 text-gray-800 border-gray-300"
    end
  end

  def status_badge_class
    case status.to_s.downcase
    when "active"     then "bg-red-100 text-red-800 border-red-300 animate-pulse font-bold"
    when "responding" then "bg-indigo-100 text-indigo-800 border-indigo-300 font-bold"
    when "monitoring" then "bg-amber-100 text-amber-800 border-amber-300 font-medium"
    when "resolved"   then "bg-green-100 text-green-800 border-green-300 font-medium"
    else "bg-gray-100 text-gray-800 border-gray-300"
    end
  end
end
