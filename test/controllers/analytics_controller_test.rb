require "test_helper"

class AnalyticsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @guwahati = Location.create!(
      name: "Guwahati",
      latitude: 26.1445,
      longitude: 91.7362,
      population: 1100000,
      accessibility_score: 95.0,
      state: "Assam",
      district: "Kamrup"
    )

    @tawang = Location.create!(
      name: "Tawang",
      latitude: 27.5855,
      longitude: 91.8679,
      population: 15000,
      accessibility_score: 10.0,
      state: "Arunachal Pradesh",
      district: "Tawang"
    )

    @warehouse = Warehouse.create!(
      name: "Guwahati Hub",
      latitude: 26.18,
      longitude: 91.75,
      capacity: 50000
    )

    @emergency = Emergency.create!(
      title: "Active Sela Mudslide",
      emergency_type: "Landslide",
      severity: "Critical",
      latitude: 27.58,
      longitude: 91.86,
      status: "Active",
      affected_radius: 50.0
    )
  end

  test "should get analytics index with all metrics and map container" do
    get analytics_url
    assert_response :success
    assert_select "h2", "Intelligence Analytics"
    assert_select "span", text: /LIVE INTELLIGENCE/
    assert_select "div[data-controller='analytics-map']"
    assert_select "h3", text: /Regional Risk Distribution/
    assert_select "h3", text: /Accessibility Intelligence/
    assert_select "h3", text: /Disaster Intelligence/
    assert_select "h3", text: /Critical Intelligence Watchlist/
  end

  test "should filter analytics by date range" do
    get analytics_url(time_range: "7d")
    assert_response :success

    get analytics_url(time_range: "30d")
    assert_response :success
  end

  test "should get printable analytics report" do
    get analytics_report_url
    assert_response :success
    assert_select "h1", "Executive Logistics & Disaster Readiness Report"
    assert_select "h2", text: /1. Executive Summary & Regional Readiness Score/
    assert_select "h2", text: /2. Logistics Readiness Formula Breakdown/
  end
end
