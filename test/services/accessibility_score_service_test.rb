require "test_helper"

class AccessibilityScoreServiceTest < ActiveSupport::TestCase
  test "calculates perfect score of 100 for optimal factors" do
    loc = Location.new(
      name: "Ideal City",
      road_quality: "excellent",
      rainfall_level: "low",
      landslide_risk: "low",
      transport_availability: "high",
      distance_to_hospital: 5.0,
      distance_to_warehouse: 10.0
    )

    result = AccessibilityScoreService.new(loc).calculate
    assert_equal 100.0, result[:score]
    assert_equal "Highly Accessible", result[:category]
    assert_equal "LOW", result[:risk_level]
  end

  test "calculates expected penalties correctly" do
    loc = Location.new(
      name: "Test Town",
      road_quality: "good",              # -5
      rainfall_level: "moderate",        # -5
      landslide_risk: "medium",          # -10
      transport_availability: "medium",  # -10
      distance_to_hospital: 25.0,        # -5
      distance_to_warehouse: 40.0        # -5
    )
    # Total penalties = 5 + 5 + 10 + 10 + 5 + 5 = 40. Score = 60.0

    result = AccessibilityScoreService.new(loc).calculate
    assert_equal 60.0, result[:score]
    assert_equal "Moderately Accessible", result[:category]
    assert_equal "MODERATE", result[:risk_level]
  end

  test "normalizes and clamps negative raw score to 0" do
    loc = Location.new(
      name: "Extreme Disaster Zone",
      road_quality: "critical",          # -45
      rainfall_level: "extreme",         # -25
      landslide_risk: "critical",        # -40
      transport_availability: "low",     # -25
      distance_to_hospital: 120.0,       # -20
      distance_to_warehouse: 150.0       # -20
    )
    # Total penalties = 175 -> clamped to 0.0

    result = AccessibilityScoreService.new(loc).calculate
    assert_equal 0.0, result[:score]
    assert_equal "Critical Accessibility", result[:category]
    assert_equal "CRITICAL", result[:risk_level]
  end

  test "identifies primary risk factor correctly" do
    loc = Location.new(
      name: "Landslide Prone Town",
      road_quality: "good",              # -5
      rainfall_level: "moderate",        # -5
      landslide_risk: "critical",        # -40 (highest)
      transport_availability: "high",    # 0
      distance_to_hospital: 5.0,         # 0
      distance_to_warehouse: 10.0        # 0
    )

    result = AccessibilityScoreService.new(loc).calculate
    assert_includes result[:primary_risk_factor], "Landslide Risk"
  end

  test "includes complete factor breakdown dictionary" do
    loc = Location.new(
      name: "Valley Village",
      road_quality: "poor",
      rainfall_level: "high",
      landslide_risk: "medium",
      transport_availability: "low",
      distance_to_hospital: 35.0,
      distance_to_warehouse: 60.0
    )

    result = AccessibilityScoreService.new(loc).calculate
    factors = result[:factors]

    assert_not_nil factors[:road_quality]
    assert_not_nil factors[:rainfall]
    assert_not_nil factors[:landslide_risk]
    assert_not_nil factors[:transport_availability]
    assert_not_nil factors[:distance_to_hospital]
    assert_not_nil factors[:distance_to_warehouse]

    assert_equal(-30, factors[:road_quality][:impact])
    assert_equal(-15, factors[:rainfall][:impact])
    assert_equal(-10, factors[:landslide_risk][:impact])
    assert_equal(-25, factors[:transport_availability][:impact])
    assert_equal(-10, factors[:distance_to_hospital][:impact])
    assert_equal(-10, factors[:distance_to_warehouse][:impact])
  end
end
