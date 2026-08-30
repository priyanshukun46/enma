require "test_helper"

class AccessibilityRecommendationServiceTest < ActiveSupport::TestCase
  test "generates critical recommendations for score under 40" do
    loc = Location.new(
      name: "Cutoff Mountain Village",
      road_quality: "critical",
      rainfall_level: "high",
      landslide_risk: "critical",
      transport_availability: "low",
      distance_to_hospital: 80.0,
      distance_to_warehouse: 120.0
    )

    recs = AccessibilityRecommendationService.new(loc).generate
    assert recs.any? { |r| r[:action].include?("Pre-position Emergency Supplies") }
    assert recs.any? { |r| r[:action].include?("Deploy Emergency Response Teams") }
    assert recs.any? { |r| r[:action].include?("Slope Stabilization") }
    assert recs.any? { |r| r[:action].include?("Medical Airlift") }
  end

  test "generates baseline monitoring recommendations for high accessibility" do
    loc = Location.new(
      name: "Guwahati Hub",
      road_quality: "excellent",
      rainfall_level: "low",
      landslide_risk: "low",
      transport_availability: "high",
      distance_to_hospital: 4.0,
      distance_to_warehouse: 5.0
    )

    recs = AccessibilityRecommendationService.new(loc).generate
    assert recs.any? { |r| r[:action].include?("Normal Monitoring") }
  end
end
