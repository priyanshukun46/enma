require "test_helper"

class EmergenciesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @location = Location.create!(
      name: "Tawang",
      latitude: 27.5855,
      longitude: 91.8679,
      population: 15000,
      accessibility_score: 10.0
    )

    @warehouse = Warehouse.create!(
      name: "Regional Hub",
      latitude: 26.18,
      longitude: 91.75,
      capacity: 50000
    )

    @emergency = Emergency.create!(
      title: "Sela Pass Landslide",
      emergency_type: "Landslide",
      severity: "Critical",
      latitude: 27.58,
      longitude: 91.86,
      affected_radius: 50.0,
      status: "Active"
    )
  end

  test "should get index" do
    get emergencies_url
    assert_response :success
    assert_select "h2", "Emergency Response Center"
    assert_select "tbody tr", minimum: 1
  end

  test "should get new simulation form" do
    get new_emergency_url
    assert_response :success
    assert_select "h2", "Simulate Emergency Disaster"
    assert_select "select[name='emergency[emergency_type]']"
  end

  test "should create emergency simulation and redirect to show" do
    assert_difference("Emergency.count", 1) do
      post emergencies_url, params: {
        emergency: {
          title: "Monsoon Flash Flood in Valley",
          emergency_type: "Flood",
          severity: "High",
          location_id: @location.id,
          affected_radius: 50.0,
          description: "Submerging road corridors."
        }
      }
    end

    new_em = Emergency.last
    assert_redirected_to emergency_path(new_em)
    follow_redirect!
    assert_response :success
    assert_select "h1", new_em.title
  end

  test "should show emergency response command center dashboard" do
    get emergency_url(@emergency)
    assert_response :success
    assert_select "h1", @emergency.title
    assert_select "div[data-controller='emergency-map']"
    assert_select "h3", text: /Why ENMA AI|Affected Communities Priority Ranking|ENMA AI Decision Timeline/
  end

  test "should update emergency status" do
    patch update_status_emergency_url(@emergency), params: { status: "Resolved" }
    assert_redirected_to emergency_path(@emergency)
    @emergency.reload
    assert_equal "Resolved", @emergency.status
  end

  test "should launch SIH demo scenario via POST" do
    assert_difference("Emergency.count", 1) do
      post demo_scenario_emergencies_url
    end

    demo_em = Emergency.last
    assert_redirected_to emergency_path(demo_em)
    follow_redirect!
    assert_response :success
    assert_select "div", text: /SIH 2026 Demo Scenario Activated/
  end
end
