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

  def recommendations
    AccessibilityRecommendationService.new(self, accessibility_analysis).generate
  end

  def primary_risk_factor
    accessibility_analysis[:primary_risk_factor]
  end

  def recalculate_accessibility_score!
    result = accessibility_analysis
    update!(accessibility_score: result[:score])
    result
  end
end
