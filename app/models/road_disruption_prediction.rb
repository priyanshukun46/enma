class RoadDisruptionPrediction < ApplicationRecord
  belongs_to :road

  serialize :input_snapshot_json, coder: JSON
  serialize :top_factors_json, coder: JSON

  validates :disruption_probability, presence: true,
            numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0 }
  validates :risk_level, presence: true, inclusion: { in: %w[low moderate high critical] }

  scope :recent, -> { order(predicted_at: :desc) }
  scope :critical, -> { where(risk_level: "critical") }
  scope :high, -> { where(risk_level: "high") }
  scope :moderate, -> { where(risk_level: "moderate") }
  scope :low, -> { where(risk_level: "low") }

  def probability_percentage
    (disruption_probability * 100.0).round(1)
  end

  def top_factors
    (top_factors_json || []).map(&:with_indifferent_access)
  end

  def input_snapshot
    (input_snapshot_json || {}).with_indifferent_access
  end

  def risk_badge_class
    case risk_level.to_s.downcase
    when "critical"
      "bg-red-100 dark:bg-red-950 text-red-800 dark:text-red-300 border-red-300 dark:border-red-800"
    when "high"
      "bg-orange-100 dark:bg-orange-950 text-orange-800 dark:text-orange-300 border-orange-300 dark:border-orange-800"
    when "moderate"
      "bg-yellow-100 dark:bg-yellow-950 text-yellow-800 dark:text-yellow-300 border-yellow-300 dark:border-yellow-800"
    else
      "bg-emerald-100 dark:bg-emerald-950 text-emerald-800 dark:text-emerald-300 border-emerald-300 dark:border-emerald-800"
    end
  end
end
