class Incident < ApplicationRecord
  belongs_to :user, optional: true
  has_many_attached :photos

  after_commit :trigger_risk_recalculation, on: [:create, :update]

  INCIDENT_TYPES = {
    "landslide" => { label: "Landslide", icon: "fa-mountain", emoji: "🪨", color: "#f97316" },
    "flood" => { label: "Flood", icon: "fa-water", emoji: "🌊", color: "#3b82f6" },
    "road_damage" => { label: "Road Damage", icon: "fa-road-barrier", emoji: "🚧", color: "#ef4444" },
    "bridge_damage" => { label: "Bridge Damage", icon: "fa-bridge-water", emoji: "🌉", color: "#dc2626" },
    "traffic_blockage" => { label: "Traffic Blockage", icon: "fa-traffic-light", emoji: "🚗", color: "#eab308" },
    "accident" => { label: "Accident", icon: "fa-car-burst", emoji: "💥", color: "#f43f5e" },
    "weather_disruption" => { label: "Weather Disruption", icon: "fa-cloud-showers-heavy", emoji: "🌧", color: "#6366f1" },
    "other" => { label: "Other Hazard", icon: "fa-triangle-exclamation", emoji: "⚠️", color: "#64748b" }
  }.freeze

  SEVERITIES = %w[low medium high critical].freeze
  STATUSES = %w[reported verified resolved rejected].freeze

  ALLOWED_IMAGE_TYPES = %w[image/jpeg image/jpg image/png image/webp].freeze
  MAX_PHOTO_SIZE = 10.megabytes
  MAX_PHOTO_COUNT = 5

  validates :incident_type, presence: true, inclusion: { in: INCIDENT_TYPES.keys }
  validates :severity, presence: true, inclusion: { in: SEVERITIES }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :description, presence: true, length: { minimum: 10, maximum: 2000 }
  validates :latitude, presence: true, numericality: { greater_than_or_equal_to: -90, less_than_or_equal_to: 90 }
  validates :longitude, presence: true, numericality: { greater_than_or_equal_to: -180, less_than_or_equal_to: 180 }
  validates :reported_at, presence: true

  validate :validate_photos

  scope :recent, -> { order(reported_at: :desc) }
  scope :active_or_reported, -> { where(status: %w[reported verified]) }
  scope :critical, -> { where(severity: "critical") }
  scope :by_type, ->(t) { where(incident_type: t) if t.present? && t != "all" }
  scope :by_severity, ->(s) { where(severity: s) if s.present? && s != "all" }
  scope :by_status, ->(st) { where(status: st) if st.present? && st != "all" }

  def type_info
    INCIDENT_TYPES[incident_type] || INCIDENT_TYPES["other"]
  end

  def type_label
    type_info[:label]
  end

  def type_emoji
    type_info[:emoji]
  end

  def type_icon
    type_info[:icon]
  end

  def type_color
    type_info[:color]
  end

  def severity_badge_class
    case severity
    when "critical"
      "bg-red-100 dark:bg-red-950 text-red-800 dark:text-red-300 border-red-300 dark:border-red-800 font-black animate-pulse"
    when "high"
      "bg-orange-100 dark:bg-orange-950 text-orange-800 dark:text-orange-300 border-orange-300 dark:border-orange-800 font-bold"
    when "medium"
      "bg-yellow-100 dark:bg-yellow-950 text-yellow-800 dark:text-yellow-300 border-yellow-300 dark:border-yellow-800 font-bold"
    when "low"
      "bg-emerald-100 dark:bg-emerald-950 text-emerald-800 dark:text-emerald-300 border-emerald-300 dark:border-emerald-800 font-medium"
    else
      "bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300 border-slate-300 dark:border-slate-700"
    end
  end

  def status_badge_class
    case status
    when "reported"
      "bg-amber-100 dark:bg-amber-950 text-amber-800 dark:text-amber-300 border-amber-300 dark:border-amber-800 font-bold"
    when "verified"
      "bg-indigo-100 dark:bg-indigo-950 text-indigo-800 dark:text-indigo-300 border-indigo-300 dark:border-indigo-800 font-black"
    when "resolved"
      "bg-emerald-100 dark:bg-emerald-950 text-emerald-800 dark:text-emerald-300 border-emerald-300 dark:border-emerald-800 font-bold"
    when "rejected"
      "bg-slate-200 dark:bg-slate-800 text-slate-600 dark:text-slate-400 border-slate-300 dark:border-slate-700"
    else
      "bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300"
    end
  end

  def formatted_reported_time
    time = reported_at || created_at || Time.current
    if time > 1.hour.ago
      "#{((Time.current - time) / 60).round} mins ago"
    elsif time > 1.day.ago
      "#{((Time.current - time) / 3600).round} hours ago"
    else
      time.strftime("%b %d, %H:%M")
    end
  end

  def confidence_data
    @confidence_data ||= begin
      if ai_classification_json.present?
        parsed = JSON.parse(ai_classification_json)
        parsed.is_a?(Hash) ? parsed.with_indifferent_access : {}
      else
        ResQWay::DataConfidenceService.new(self).calculate.with_indifferent_access
      end
    rescue StandardError
      {}
    end
  end

  def confidence_score
    ai_confidence_score || confidence_data[:overall_confidence] || 70.0
  end

  def confidence_level
    return confidence_data[:confidence_level] if confidence_data[:confidence_level].present?

    score = confidence_score.to_f
    if score >= 90.0
      "VERIFIED"
    elsif score >= 75.0
      "HIGH"
    elsif score >= 55.0
      "MODERATE"
    else
      "LOW"
    end
  end

  def confidence_badge_class
    case confidence_level
    when "VERIFIED"
      "bg-emerald-100 dark:bg-emerald-950 text-emerald-800 dark:text-emerald-300 border-emerald-300 dark:border-emerald-800 font-bold"
    when "HIGH"
      "bg-blue-100 dark:bg-blue-950 text-blue-800 dark:text-blue-300 border-blue-300 dark:border-blue-800 font-semibold"
    when "MODERATE"
      "bg-amber-100 dark:bg-amber-950 text-amber-800 dark:text-amber-300 border-amber-300 dark:border-amber-800 font-medium"
    when "LOW"
      "bg-rose-100 dark:bg-rose-950 text-rose-800 dark:text-rose-300 border-rose-300 dark:border-rose-800 font-medium"
    else
      "bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300 border-slate-300 dark:border-slate-700"
    end
  end

  def confidence_verified?
    confidence_level == "VERIFIED"
  end

  def high_confidence?
    confidence_score.to_f >= 75.0
  end


  def as_map_json(view_context = nil)
    photo_urls = []
    if photos.attached?
      photo_urls = photos.map do |photo|
        if view_context
          view_context.url_for(photo)
        else
          Rails.application.routes.url_helpers.rails_blob_path(photo, only_path: true)
        end
      rescue StandardError
        nil
      end.compact
    end

    {
      id: id,
      incident_type: incident_type,
      type_label: type_label,
      type_emoji: type_emoji,
      type_icon: type_icon,
      type_color: type_color,
      severity: severity,
      severity_label: severity.titleize,
      severity_badge_class: severity_badge_class,
      status: status,
      status_label: status.titleize,
      status_badge_class: status_badge_class,
      description: description,
      latitude: latitude,
      longitude: longitude,
      location_name: location_name.presence || "Field Coordinates (#{latitude.round(4)}, #{longitude.round(4)})",
      district: district,
      state: state,
      reported_at: formatted_reported_time,
      reporter_name: user&.name || "Field Officer",
      photos_count: photos.attached? ? photos.count : 0,
      first_photo_url: photo_urls.first,
      photo_urls: photo_urls,
      confidence_score: confidence_score.round(1),
      confidence_level: confidence_level,
      confidence_badge_class: confidence_badge_class,
      url: Rails.application.routes.url_helpers.incident_path(self)
    }
  end

  private

  def trigger_risk_recalculation
    # Recalculate road risk for all roads in the affected state or near coordinates
    Road.where(state: state).find_each do |road|
      ResQWay::RoadRiskIntelligenceService.new(road).calculate_and_update!(trigger_source: "incident_reported")
    rescue StandardError => e
      Rails.logger.error("Failed to recalculate road risk for road #{road.id}: #{e.message}")
    end
  end

  def validate_photos
    return unless photos.attached?

    if photos.count > MAX_PHOTO_COUNT
      errors.add(:photos, "can have a maximum of #{MAX_PHOTO_COUNT} photos per incident report.")
    end

    photos.each do |photo|
      if photo.blob.byte_size > MAX_PHOTO_SIZE
        errors.add(:photos, "#{photo.filename} is too large. Maximum allowed size is 10 MB.")
      end

      unless ALLOWED_IMAGE_TYPES.include?(photo.content_type)
        errors.add(:photos, "#{photo.filename} is not an accepted format. Please upload JPG, PNG, or WebP images.")
      end
    end
  end
end
