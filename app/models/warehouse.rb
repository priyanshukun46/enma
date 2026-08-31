class Warehouse < ApplicationRecord
  belongs_to :location, optional: true

  serialize :resources_json, coder: JSON

  scope :operational, -> { where(operational_status: "OPERATIONAL") }
  scope :limited, -> { where(operational_status: "LIMITED") }
  scope :overloaded, -> { where(operational_status: "OVERLOADED") }
  scope :available, -> { where.not(operational_status: "UNAVAILABLE") }
  scope :by_readiness, -> { order(readiness_score: :desc) }

  RESOURCE_CATEGORIES = {
    medical_kits: { label: "Medical Kits", icon: "fa-kit-medical", unit: "kits" },
    food_packages: { label: "Food Packages", icon: "fa-box", unit: "packages" },
    water_units: { label: "Water Supply", icon: "fa-droplet", unit: "liters" },
    emergency_shelters: { label: "Emergency Shelters", icon: "fa-campground", unit: "units" },
    fuel_liters: { label: "Fuel Reserve", icon: "fa-gas-pump", unit: "liters" },
    rescue_equipment: { label: "Rescue Equipment", icon: "fa-life-ring", unit: "sets" }
  }.freeze

  # =========================================================================
  # Capacity & Utilization
  # =========================================================================
  def available_capacity
    (capacity || 0) - (utilized_capacity || 0)
  end

  def utilization_percentage
    return 0.0 if capacity.nil? || capacity.zero?
    ((utilized_capacity || 0).to_f / capacity.to_f * 100.0).round(1)
  end

  # =========================================================================
  # Dynamic Operational Status
  # =========================================================================
  def dynamic_status
    return "UNAVAILABLE" if operational_status == "UNAVAILABLE"
    util = utilization_percentage
    if util < 60.0
      "OPERATIONAL"
    elsif util <= 85.0
      "LIMITED"
    else
      "OVERLOADED"
    end
  end

  def update_dynamic_status!
    update_column(:operational_status, dynamic_status)
  end

  # =========================================================================
  # Resource Inventory Helpers
  # =========================================================================
  def resources
    data = resources_json
    if data.is_a?(String)
      data = begin
        JSON.parse(data)
      rescue JSON::ParserError
        default_resources
      end
    end
    (data.is_a?(Hash) && data.present? ? data : default_resources).with_indifferent_access
  end

  def resource_count(category)
    resources[category.to_s].to_i
  end

  def total_available_resources
    res = resources
    res.values.sum(&:to_i)
  end

  def critical_resource_coverage
    res = resources
    critical = [:medical_kits, :food_packages, :water_units]
    total = critical.sum { |k| res[k.to_s].to_i }
    max_possible = critical.size * 5000
    [(total.to_f / max_possible * 100.0).round(1), 100.0].min
  end

  def emergency_type_resource_match(emergency_type)
    type = emergency_type.to_s.downcase
    res = resources
    case type
    when "flood"
      score_resources(res, water_units: 3, emergency_shelters: 2, rescue_equipment: 2, food_packages: 1)
    when "landslide"
      score_resources(res, rescue_equipment: 3, medical_kits: 2, food_packages: 1, fuel_liters: 1)
    when "medical emergency"
      score_resources(res, medical_kits: 4, fuel_liters: 1)
    when "supply shortage"
      score_resources(res, food_packages: 3, water_units: 3, fuel_liters: 1)
    when "severe weather", "heavy rainfall"
      score_resources(res, emergency_shelters: 2, food_packages: 2, water_units: 2, rescue_equipment: 1)
    when "road blockage"
      score_resources(res, rescue_equipment: 3, fuel_liters: 2, food_packages: 1)
    else
      score_resources(res, medical_kits: 1, food_packages: 1, water_units: 1, rescue_equipment: 1)
    end
  end

  # =========================================================================
  # Readiness Calculation
  # =========================================================================
  def calculate_readiness_score
    # Capacity factor (30%): available capacity ratio
    cap_ratio = capacity.to_i > 0 ? (available_capacity.to_f / capacity.to_f) : 0.5
    cap_factor = (cap_ratio * 100.0) * 0.30

    # Resource factor (35%): critical resource coverage
    res_factor = critical_resource_coverage * 0.35

    # Operational status factor (20%)
    status_factor = case dynamic_status
                    when "OPERATIONAL" then 100.0
                    when "LIMITED" then 60.0
                    when "OVERLOADED" then 25.0
                    else 0.0
                    end * 0.20

    # Infrastructure factor (15%): location accessibility
    infra_factor = if location
                     (location.accessibility_score || 50.0) * 0.15
                   else
                     50.0 * 0.15
                   end

    (cap_factor + res_factor + status_factor + infra_factor).clamp(0.0, 100.0).round(1)
  end

  def update_readiness!
    update_columns(
      readiness_score: calculate_readiness_score,
      operational_status: dynamic_status
    )
  end

  # =========================================================================
  # Badge Styling
  # =========================================================================
  def status_badge_class
    case dynamic_status
    when "OPERATIONAL"
      "bg-emerald-100 dark:bg-emerald-950 text-emerald-800 dark:text-emerald-300 border-emerald-300 dark:border-emerald-800"
    when "LIMITED"
      "bg-amber-100 dark:bg-amber-950 text-amber-800 dark:text-amber-300 border-amber-300 dark:border-amber-800"
    when "OVERLOADED"
      "bg-red-100 dark:bg-red-950 text-red-800 dark:text-red-300 border-red-300 dark:border-red-800"
    when "UNAVAILABLE"
      "bg-slate-200 dark:bg-slate-800 text-slate-600 dark:text-slate-400 border-slate-300 dark:border-slate-700"
    else
      "bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300"
    end
  end

  def readiness_color_class
    score = readiness_score || 0
    if score >= 75.0
      "text-emerald-600 dark:text-emerald-400"
    elsif score >= 50.0
      "text-amber-600 dark:text-amber-400"
    else
      "text-red-600 dark:text-red-400"
    end
  end

  private

  def default_resources
    {
      "medical_kits" => 200,
      "food_packages" => 500,
      "water_units" => 1000,
      "emergency_shelters" => 50,
      "fuel_liters" => 2000,
      "rescue_equipment" => 30
    }
  end

  def score_resources(res, weights = {})
    total_weight = weights.values.sum.to_f
    return 50.0 if total_weight.zero?

    weighted_score = weights.sum do |key, weight|
      available = res[key.to_s].to_i
      threshold = key.to_s.include?("fuel") || key.to_s.include?("water") ? 3000 : 500
      item_score = [(available.to_f / threshold * 100.0), 100.0].min
      item_score * (weight.to_f / total_weight)
    end

    weighted_score.clamp(0.0, 100.0).round(1)
  end
end
