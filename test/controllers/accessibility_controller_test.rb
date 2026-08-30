require "test_helper"

class AccessibilityControllerTest < ActionDispatch::IntegrationTest
  setup do
    @loc1 = Location.create!(
      name: "Tawang",
      location_type: "Monastery Town",
      latitude: 27.58,
      longitude: 91.86,
      population: 15000,
      state: "Arunachal Pradesh",
      district: "Tawang",
      road_quality: "poor",
      rainfall_level: "high",
      landslide_risk: "critical",
      transport_availability: "low",
      distance_to_hospital: 65.0,
      distance_to_warehouse: 110.0,
      accessibility_score: 0.0
    )

    @loc2 = Location.create!(
      name: "Guwahati",
      location_type: "City",
      latitude: 26.14,
      longitude: 91.73,
      population: 1100000,
      state: "Assam",
      district: "Kamrup Metropolitan",
      road_quality: "excellent",
      rainfall_level: "low",
      landslide_risk: "low",
      transport_availability: "high",
      distance_to_hospital: 3.5,
      distance_to_warehouse: 8.0,
      accessibility_score: 100.0
    )
  end

  test "should get index and display ranked locations" do
    get accessibility_url
    assert_response :success
    assert_select "h2", "Accessibility Intelligence"
    # Should list Tawang before Guwahati (lowest score first)
    assert_select "tbody tr:first-child", /Tawang/
  end

  test "should get show for specific location" do
    get accessibility_location_url(@loc1)
    assert_response :success
    assert_select "h1", "Tawang"
    assert_select "div", text: /Factors Affecting Accessibility/
    assert_select "div", text: /Actionable Logistics & Emergency Recommendations/
  end

  test "should recalculate scores via POST action" do
    # Alter factor on loc2
    @loc2.update_columns(accessibility_score: nil)

    post recalculate_accessibility_url
    assert_redirected_to accessibility_path
    follow_redirect!
    assert_response :success

    @loc2.reload
    assert_equal 100.0, @loc2.accessibility_score
  end
end
