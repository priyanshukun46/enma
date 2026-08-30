require "test_helper"

class LocationTest < ActiveSupport::TestCase
  test "accessibility category and risk level helpers" do
    loc = Location.new(accessibility_score: 92.0)
    assert_equal "Highly Accessible", loc.accessibility_category
    assert_equal "LOW", loc.risk_level

    loc.accessibility_score = 65.0
    assert_equal "Moderately Accessible", loc.accessibility_category
    assert_equal "MODERATE", loc.risk_level

    loc.accessibility_score = 45.0
    assert_equal "Difficult Access", loc.accessibility_category
    assert_equal "HIGH", loc.risk_level

    loc.accessibility_score = 25.0
    assert_equal "Critical Accessibility", loc.accessibility_category
    assert_equal "CRITICAL", loc.risk_level
  end

  test "recalculate_accessibility_score! updates score in database" do
    loc = Location.create!(
      name: "Kohima",
      road_quality: "good",
      rainfall_level: "moderate",
      landslide_risk: "medium",
      transport_availability: "medium",
      distance_to_hospital: 6.5,
      distance_to_warehouse: 26.0
    )

    loc.recalculate_accessibility_score!
    assert_equal 65.0, loc.accessibility_score
  end
end
