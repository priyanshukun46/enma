require "test_helper"

class SearchControllerTest < ActionDispatch::IntegrationTest
  test "should get search page without query" do
    get search_url
    assert_response :success
    assert_select "h2", "Global Search"
  end

  test "should search for locations by name" do
    get search_url, params: { q: "Guwahati" }
    assert_response :success
    assert_select "div", text: /Guwahati/
  end

  test "should return search suggestions JSON with preset suggestions when query is empty" do
    get search_suggestions_url
    assert_response :success
    json = JSON.parse(response.body)
    assert json["suggestions"].is_a?(Array)
    assert json["suggestions"].any?
  end

  test "should return filtered search suggestions JSON for matching query" do
    Location.create!(
      name: "Tawang Frontier Base",
      state: "Arunachal Pradesh",
      district: "Tawang",
      latitude: 27.58,
      longitude: 91.86,
      population: 11000,
      accessibility_score: 45.0
    )
    get search_suggestions_url, params: { q: "Tawang" }
    assert_response :success
    json = JSON.parse(response.body)
    assert json["suggestions"].is_a?(Array)
    assert json["suggestions"].any? { |s| s["title"] =~ /Tawang/i }
  end

  test "should search and find matching roads" do
    Road.create!(
      name: "Trans-Arunachal Lifeline",
      road_number: "NH-13-EXP",
      state: "Arunachal Pradesh",
      district: "Tawang",
      status: "accessible",
      risk_score: 65.0,
      risk_level: "moderate"
    )
    get search_url, params: { q: "NH-13-EXP" }
    assert_response :success
    assert_select "h4", text: /NH-13-EXP/
  end
end
