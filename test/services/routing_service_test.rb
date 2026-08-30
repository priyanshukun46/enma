require "test_helper"

class RoutingServiceTest < ActiveSupport::TestCase
  setup do
    @guwahati = Location.create!(
      name: "Guwahati",
      latitude: 26.1445,
      longitude: 91.7362,
      accessibility_score: 95.0
    )

    @shillong = Location.create!(
      name: "Shillong",
      latitude: 25.5788,
      longitude: 91.8933,
      accessibility_score: 90.0
    )
  end

  test "returns normalized alternative routes" do
    service = RoutingService.new(origin: @guwahati, destination: @shillong)
    routes = service.alternatives

    assert_instance_of Array, routes
    assert routes.size >= 1

    first_route = routes.first
    assert_not_nil first_route[:id]
    assert first_route[:distance_km] > 50.0
    assert first_route[:duration_minutes] > 0
    assert first_route[:coordinates].is_a?(Array)
    assert first_route[:coordinates].size >= 2
    assert %w[osrm fallback_haversine].include?(first_route[:source])
  end

  test "fallback generation produces curved waypoints and turn instructions" do
    service = RoutingService.new(origin: @guwahati, destination: @shillong)
    fallback_routes = service.send(:generate_fallback_routes)

    assert_equal 3, fallback_routes.size

    fallback_routes.each do |r|
      assert r[:fallback_used]
      assert_equal "fallback_haversine", r[:source]
      assert r[:coordinates].size >= 8
      assert r[:steps].any?
      assert_equal 1, r[:steps].first[:step_number]
    end
  end
end
