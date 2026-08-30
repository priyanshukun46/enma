require "test_helper"

class EmergencyResponseServiceTest < ActiveSupport::TestCase
  setup do
    @guwahati = Location.create!(
      name: "Guwahati",
      latitude: 26.1445,
      longitude: 91.7362,
      population: 1100000,
      accessibility_score: 95.0
    )

    @shillong = Location.create!(
      name: "Shillong",
      latitude: 25.5788,
      longitude: 91.8933,
      population: 150000,
      accessibility_score: 90.0
    )

    @cherra = Location.create!(
      name: "Cherrapunjee",
      latitude: 25.2758,
      longitude: 91.7226,
      population: 10000,
      accessibility_score: 30.0
    )

    @warehouse = Warehouse.create!(
      name: "Guwahati Hub",
      latitude: 26.1800,
      longitude: 91.7500,
      capacity: 50000
    )

    @emergency = Emergency.create!(
      title: "Landslide near Cherrapunjee",
      emergency_type: "Landslide",
      severity: "Critical",
      latitude: 25.2800,
      longitude: 91.7200,
      affected_radius: 50.0,
      status: "Active"
    )
  end

  test "detects affected locations within radius and calculates priority scores" do
    service = EmergencyResponseService.new(@emergency)
    result = service.analyze

    assert result[:affected_count] >= 1
    cherra_comm = result[:affected_communities].find { |c| c[:name] == "Cherrapunjee" }
    assert_not_nil cherra_comm
    assert cherra_comm[:distance_km] < 50.0
    assert cherra_comm[:priority_score] >= 0.0 && cherra_comm[:priority_score] <= 100.0
  end

  test "identifies critical communities correctly" do
    service = EmergencyResponseService.new(@emergency)
    result = service.analyze

    # Cherrapunjee has accessibility_score < 40 and critical emergency nearby
    assert result[:critical_communities].any? { |c| c[:name] == "Cherrapunjee" }
  end

  test "recommends optimal warehouse with reasoning" do
    service = EmergencyResponseService.new(@emergency)
    result = service.analyze

    wh = result[:recommended_warehouse]
    assert_not_nil wh
    assert_equal @warehouse.name, wh[:name]
    assert wh[:recommendation_score] >= 0 && wh[:recommendation_score] <= 100
    assert_not_empty wh[:selection_reasoning]
  end

  test "generates response directives and 6-step decision timeline" do
    service = EmergencyResponseService.new(@emergency)
    result = service.analyze

    assert result[:response_directives].any?
    assert_equal 6, result[:decision_timeline].size
    assert_equal 1, result[:decision_timeline].first[:step]
    assert_equal 6, result[:decision_timeline].last[:step]
  end
end
