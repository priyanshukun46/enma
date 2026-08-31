require "test_helper"

class RoadTest < ActiveSupport::TestCase
  setup do
    @road = Road.create!(
      name: "Guwahati-Nagaon Expressway",
      road_number: "NH-27",
      district: "Kamrup",
      state: "Assam",
      status: "accessible",
      risk_score: 20.0,
      reason: "Nominal highway condition",
      length_km: 120.0,
      geometry_coordinates: [[26.1, 91.7], [26.2, 92.1], [26.3, 92.6]]
    )
  end

  test "validates required fields" do
    road = Road.new
    assert_not road.valid?
    assert_includes road.errors[:name], "can't be blank"
    assert_includes road.errors[:road_number], "can't be blank"
    assert_includes road.errors[:state], "can't be blank"
  end

  test "validates status inclusion" do
    @road.status = "invalid_status"
    assert_not @road.valid?
    assert_includes @road.errors[:status], "is not included in the list"
  end

  test "validates risk_score range" do
    @road.risk_score = 150.0
    assert_not @road.valid?

    @road.risk_score = -5.0
    assert_not @road.valid?

    @road.risk_score = 50.0
    assert @road.valid?
  end

  test "coordinates serialization and parsing" do
    assert_equal 3, @road.coordinates.size
    assert_equal [26.1, 91.7], @road.coordinates.first
  end

  test "status color mapping" do
    @road.status = "accessible"
    assert_equal "#10b981", @road.status_color

    @road.status = "moderate_risk"
    assert_equal "#eab308", @road.status_color

    @road.status = "high_risk"
    assert_equal "#f97316", @road.status_color

    @road.status = "blocked"
    assert_equal "#ef4444", @road.status_color
  end

  test "scopes filter correctly" do
    Road.create!(
      name: "Tawang Detour",
      road_number: "NH-229",
      state: "Arunachal Pradesh",
      status: "blocked",
      risk_score: 95.0,
      geometry_coordinates: [[27.5, 91.8], [27.3, 92.2]]
    )

    assert_includes Road.accessible, @road
    assert_equal 1, Road.blocked.where(road_number: "NH-229").count
    assert_equal 1, Road.by_state("Arunachal Pradesh").count
  end

  test "as_map_json output contains necessary Leaflet properties" do
    json = @road.as_map_json
    assert_equal "NH-27", json[:road_number]
    assert_equal "accessible", json[:status]
    assert_equal "#10b981", json[:status_color]
    assert_equal 3, json[:coordinates].size
  end
end
