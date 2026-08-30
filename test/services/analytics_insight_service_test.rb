require "test_helper"

class AnalyticsInsightServiceTest < ActiveSupport::TestCase
  setup do
    @tawang = Location.create!(
      name: "Tawang",
      latitude: 27.5855,
      longitude: 91.8679,
      population: 15000,
      accessibility_score: 10.0
    )

    @warehouse = Warehouse.create!(
      name: "Guwahati Regional Depot",
      latitude: 26.18,
      longitude: 91.75,
      capacity: 50000
    )

    @emergency = Emergency.create!(
      title: "Active Mudslide",
      emergency_type: "Landslide",
      severity: "Critical",
      latitude: 27.58,
      longitude: 91.86,
      status: "Active",
      affected_radius: 50.0
    )
  end

  test "generates dynamic rule-based insights for critical zones, warehouses, and emergencies" do
    service = AnalyticsInsightService.new
    insights = service.generate_insights

    assert_equal 4, insights.size
    assert insights.any? { |i| i[:type] == "critical" }
    assert insights.any? { |i| i[:type] == "positive" }
    assert insights.any? { |i| i[:type] == "alert" }
    assert insights.any? { |i| i[:type] == "recommendation" }
  end
end
