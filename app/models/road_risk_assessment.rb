class RoadRiskAssessment < ApplicationRecord
  belongs_to :road

  serialize :factors_breakdown_json, coder: JSON

  validates :risk_score, presence: true, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 100.0 }
  validates :risk_level, presence: true
  validates :calculated_at, presence: true

  scope :recent, -> { order(calculated_at: :desc) }

  def factors
    (factors_breakdown_json || {}).with_indifferent_access
  end
end
