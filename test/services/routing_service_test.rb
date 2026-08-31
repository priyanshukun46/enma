require "test_helper"

class RoutingServiceTest < ActiveSupport::TestCase
  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    @origin = Location.create!(
      name: "Guwahati Hub",
      latitude: 26.14,
      longitude: 91.73,
      state: "Assam",
      district: "Kamrup"
    )
    @destination = Location.create!(
      name: "Shillong Post",
      latitude: 25.57,
      longitude: 91.89,
      state: "Meghalaya",
      district: "East Khasi Hills"
    )
  end

  teardown do
    Rails.cache = @original_cache
  end

  test "returns normalized routes on successful live OSRM response" do
    mock_routes = [
      {
        id: "route_1",
        index: 0,
        name: "GS Road / NH6",
        distance_km: 98.2,
        duration_minutes: 145,
        estimated_hours: 2.42,
        geometry: [[26.14, 91.73], [25.80, 91.80], [25.57, 91.89]],
        coordinates: [[26.14, 91.73], [25.80, 91.80], [25.57, 91.89]],
        steps: [
          { step_number: 1, instruction: "Head south on GS Road", distance_km: 12.0, road_name: "GS Road" }
        ],
        source: "live",
        fallback_used: false,
        summary: "Primary National Highway Track"
      },
      {
        id: "route_2",
        index: 1,
        name: "Byrnihat Bypass",
        distance_km: 104.5,
        duration_minutes: 160,
        estimated_hours: 2.67,
        geometry: [[26.14, 91.73], [25.90, 91.85], [25.57, 91.89]],
        coordinates: [[26.14, 91.73], [25.90, 91.85], [25.57, 91.89]],
        steps: [
          { step_number: 1, instruction: "Head southeast via Byrnihat", distance_km: 18.0, road_name: "Bypass Link" }
        ],
        source: "live",
        fallback_used: false,
        summary: "Secondary Mountain Track"
      }
    ]

    service = RoutingService.new(origin: @origin, destination: @destination)
    with_fake_osrm(service, mock_routes) do
      routes = service.alternatives

      assert_equal 2, routes.size
      first_route = routes.first

      assert_equal "route_1", first_route[:id]
      assert_equal 98.2, first_route[:distance_km]
      assert_equal 145, first_route[:duration_minutes]
      assert_equal "live", first_route[:source]
      assert_equal false, first_route[:fallback_used]
      assert_equal 3, first_route[:geometry].size
      assert_equal 1, first_route[:steps].size
    end
  end

  test "falls back to high-fidelity terrain corridors on API timeout or failure" do
    service = RoutingService.new(origin: @origin, destination: @destination)
    with_fake_osrm(service, -> { raise Net::ReadTimeout, "Execution expired" }) do
      routes = service.alternatives

      assert routes.size >= 3
      routes.each do |r|
        assert_equal "demo_fallback", r[:source]
        assert_equal true, r[:fallback_used]
        assert r[:distance_km] > 0.0
        assert r[:duration_minutes] > 0
        assert r[:coordinates].any?
        assert r[:steps].any?
      end
    end
  end

  test "caches route calculations across repeated calls" do
    call_count = 0
    mock_routes = [
      {
        id: "route_1",
        index: 0,
        name: "Direct Route",
        distance_km: 80.0,
        duration_minutes: 100,
        estimated_hours: 1.67,
        geometry: [[26.14, 91.73], [25.57, 91.89]],
        coordinates: [[26.14, 91.73], [25.57, 91.89]],
        steps: [],
        source: "live",
        fallback_used: false
      }
    ]

    service1 = RoutingService.new(origin: @origin, destination: @destination)
    with_fake_osrm(service1, -> { call_count += 1; mock_routes }) do
      r1 = service1.alternatives
      assert_equal 1, r1.size
      assert_equal 1, call_count
    end

    service2 = RoutingService.new(origin: @origin, destination: @destination)
    with_fake_osrm(service2, -> { raise "Should read from cache without API call" }) do
      r2 = service2.alternatives
      assert_equal 1, r2.size
      assert_equal "route_1", r2.first[:id]
      assert_equal 1, call_count, "Expected cache to be used without increasing call count"
    end
  end

  test "parse_osrm_routes correctly extracts distance, duration, steps and geometry" do
    service = RoutingService.new(origin: @origin, destination: @destination)
    osrm_data = [
      {
        "distance" => 95000.0, # 95 km
        "duration" => 7200.0,  # 120 mins
        "geometry" => {
          "coordinates" => [
            [91.73, 26.14],
            [91.80, 25.80],
            [91.89, 25.57]
          ]
        },
        "legs" => [
          {
            "summary" => "National Highway 6",
            "steps" => [
              {
                "name" => "NH 6",
                "distance" => 45000.0,
                "duration" => 3600.0,
                "maneuver" => { "type" => "depart", "modifier" => "straight", "location" => [91.73, 26.14] }
              }
            ]
          }
        ]
      }
    ]

    parsed = service.send(:parse_osrm_routes, osrm_data)
    assert_equal 1, parsed.size
    route = parsed.first

    assert_equal "route_1", route[:id]
    assert_equal 95.0, route[:distance_km]
    assert_equal 120, route[:duration_minutes]
    assert_equal "live", route[:source]
    assert_equal false, route[:fallback_used]
    assert_equal [26.14, 91.73], route[:geometry].first
    assert_equal 1, route[:steps].size
    assert_equal "NH 6", route[:steps].first[:road_name]
  end

  private

  def with_fake_osrm(service, payload_or_proc)
    eigenclass = class << service; self; end
    if payload_or_proc.is_a?(Proc)
      eigenclass.define_method(:fetch_osrm_routes, &payload_or_proc)
    else
      eigenclass.define_method(:fetch_osrm_routes) { payload_or_proc }
    end
    yield
  ensure
    eigenclass.remove_method(:fetch_osrm_routes) if eigenclass.method_defined?(:fetch_osrm_routes)
  end
end
