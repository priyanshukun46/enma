class Location < ApplicationRecord
  validates :name, presence: true

  scope :ordered_by_risk, -> { order(accessibility_score: :asc) }
  scope :critical_accessibility, -> { where("accessibility_score < ?", 40) }
  scope :difficult_accessibility, -> { where("accessibility_score >= ? AND accessibility_score < ?", 40, 60) }
  scope :moderate_accessibility, -> { where("accessibility_score >= ? AND accessibility_score < ?", 60, 80) }
  scope :highly_accessible, -> { where("accessibility_score >= ?", 80) }

  def accessibility_category
    AccessibilityScoreService.category_for(accessibility_score)
  end

  def risk_level
    AccessibilityScoreService.risk_level_for(accessibility_score)
  end

  def accessibility_analysis
    AccessibilityScoreService.new(self).calculate
  end

  def accessibility_tier
    accessibility_category
  end

  def accessibility_badge_class
    score = accessibility_score.to_f
    if score < 40.0
      "bg-red-100 dark:bg-red-950/80 text-red-700 dark:text-red-300 border-red-200 dark:border-red-800"
    elsif score < 60.0
      "bg-orange-100 dark:bg-orange-950/80 text-orange-700 dark:text-orange-300 border-orange-200 dark:border-orange-800"
    elsif score < 80.0
      "bg-yellow-100 dark:bg-yellow-950/80 text-yellow-700 dark:text-yellow-300 border-yellow-200 dark:border-yellow-800"
    else
      "bg-emerald-100 dark:bg-emerald-950/80 text-emerald-700 dark:text-emerald-300 border-emerald-200 dark:border-emerald-800"
    end
  end

  def recommendations
    AccessibilityRecommendationService.new(self, accessibility_analysis).generate
  end

  def primary_risk_factor
    accessibility_analysis[:primary_risk_factor]
  end

  def current_weather(force_refresh: false)
    WeatherService.fetch(latitude, longitude, fallback_location: self, force_refresh: force_refresh)
  end

  def recalculate_accessibility_score!
    result = accessibility_analysis
    update!(accessibility_score: result[:score])
    result
  end
end
