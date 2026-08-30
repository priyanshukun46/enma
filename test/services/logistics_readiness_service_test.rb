require "test_helper"

class LogisticsReadinessServiceTest < ActiveSupport::TestCase
  setup do
    @guwahati = Location.create!(
      name: "Guwahati",
      latitude: 26.1445,
      longitude: 91.7362,
      population: 1100000,
      accessibility_score: 95.0
    )

    @tawang = Location.create!(
      name: "Tawang",
      latitude: 27.5855,
      longitude: 91.8679,
      population: 15000,
      accessibility_score: 10.0
    )

    @warehouse = Warehouse.create!(
      name: "Guwahati Regional Hub",
      latitude: 26.1800,
      longitude: 91.7500,
      capacity: 50000
    )

    @emergency = Emergency.create!(
      title: "Active Flash Flood",
      emergency_type: "Flood",
      severity: "High",
      latitude: 26.10,
      longitude: 91.70,
      status: "Active",
      affected_radius: 50.0
    )
  end

  test "calculates readiness score within 0 to 100 bounds and returns all components" do
    service = LogisticsReadinessService.new
    result = service.calculate

    assert result[:score] >= 0.0 && result[:score] <= 100.0
    assert_includes %w[HIGHLY\ PREPARED PREPARED MODERATE\ READINESS VULNERABLE], result[:category]
    assert_not_nil result[:breakdown][:accessibility_percentage]
    assert_not_nil result[:breakdown][:warehouse_coverage_percentage]
    assert_not_nil result[:breakdown][:emergency_preparedness_percentage]
    assert_not_nil result[:breakdown][:risk_resilience_percentage]
    assert_not_empty result[:explanation]
    assert_not_empty result[:recommendation]
  end
end
