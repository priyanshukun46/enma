# frozen_string_literal: true

require "test_helper"

class NetworkConnectivityServiceTest < ActiveSupport::TestCase
  def setup
    LogisticsAlert.delete_all
    Road.delete_all
    Warehouse.delete_all
    Location.delete_all

    # Setup 4 distinct locations representing a linear + branch network:
    # Guwahati (Hub/Warehouse) --- (NH-27) ---> Jorhat
    # Guwahati (Hub/Warehouse) --- (NH-06) ---> Shillong --- (SH-05) ---> Cherrapunjee
    @guwahati = Location.create!(
      name: "Guwahati",
      state: "Assam",
      district: "Kamrup",
      location_type: "City",
      population: 1000000,
      latitude: 26.1445,
      longitude: 91.7362,
      road_quality: "excellent",
      rainfall_level: "low",
      landslide_risk: "low",
      transport_availability: "high"
    )

    @jorhat = Location.create!(
      name: "Jorhat",
      state: "Assam",
      district: "Jorhat",
      location_type: "Town",
      population: 120000,
      latitude: 26.7509,
      longitude: 94.2037,
      road_quality: "good",
      rainfall_level: "moderate",
      landslide_risk: "low",
      transport_availability: "high"
    )

    @shillong = Location.create!(
      name: "Shillong",
      state: "Meghalaya",
      district: "East Khasi Hills",
      location_type: "Capital City",
      population: 150000,
      latitude: 25.5788,
      longitude: 91.8933,
      road_quality: "good",
      rainfall_level: "moderate",
      landslide_risk: "low",
      transport_availability: "high"
    )

    @cherra = Location.create!(
      name: "Cherrapunjee",
      state: "Meghalaya",
      district: "East Khasi Hills",
      location_type: "Town",
      population: 15000,
      latitude: 25.2758,
      longitude: 91.7226,
      road_quality: "moderate",
      rainfall_level: "extreme",
      landslide_risk: "medium",
      transport_availability: "medium"
    )

    # Warehouse stationed at Guwahati
    @warehouse = Warehouse.create!(
      name: "Guwahati Central Depot",
      location: @guwahati,
      latitude: 26.1445,
      longitude: 91.7362,
      operational_status: "OPERATIONAL",
      readiness_score: 95.0,
      capacity: 10000,
      utilized_capacity: 3500
    )

    # Road 1: Guwahati to Jorhat
    @road_nh27 = Road.create!(
      name: "Guwahati – Jorhat Arterial",
      road_number: "NH-27",
      state: "Assam",
      status: "accessible",
      risk_score: 15.0,
      length_km: 300.0,
      geometry_coordinates: [
        [26.1445, 91.7362],
        [26.7509, 94.2037]
      ]
    )

    # Road 2: Guwahati to Shillong
    @road_nh06 = Road.create!(
      name: "Guwahati – Shillong Highway",
      road_number: "NH-06",
      state: "Meghalaya",
      status: "accessible",
      risk_score: 25.0,
      length_km: 100.0,
      geometry_coordinates: [
        [26.1445, 91.7362],
        [25.5788, 91.8933]
      ]
    )

    # Road 3: Shillong to Cherrapunjee (Single Point of Failure for Cherrapunjee)
    @road_sh05 = Road.create!(
      name: "Shillong – Cherrapunjee Mountain Route",
      road_number: "SH-05",
      state: "Meghalaya",
      status: "accessible",
      risk_score: 40.0,
      length_km: 55.0,
      geometry_coordinates: [
        [25.5788, 91.8933],
        [25.2758, 91.7226]
      ]
    )
  end

  # =========================================================================
  # 1. FULLY CONNECTED GRAPH
  # =========================================================================
  test "1. fully connected graph produces single component, 0 isolated settlements, and 100% health score" do
    service = Enma::NetworkConnectivityService.new(
      locations: [@guwahati, @jorhat, @shillong, @cherra],
      roads: [@road_nh27, @road_nh06, @road_sh05],
      warehouses: [@warehouse]
    )

    analysis = service.analyze

    assert_equal 1, analysis[:connected_components_count]
    assert_equal 4, analysis[:connected_settlements_count]
    assert_equal 0, analysis[:isolated_settlements_count]
    assert_equal 0.0, analysis[:isolation_impact_score]
    assert_equal 100.0, analysis[:network_health_score]
    assert_equal "STABLE", analysis[:network_health_trend]
    assert_equal 4, analysis[:largest_component_size]
  end

  # =========================================================================
  # 2. MULTIPLE CONNECTED COMPONENTS (DISCONNECTED CLUSTERS)
  # =========================================================================
  test "2. analyzes network with multiple disconnected clusters" do
    @road_nh27.update!(status: "blocked")
    @road_nh06.update!(status: "blocked")

    service = Enma::NetworkConnectivityService.new(
      locations: [@guwahati, @jorhat, @shillong, @cherra],
      roads: [@road_nh27, @road_nh06, @road_sh05],
      warehouses: [@warehouse]
    )

    analysis = service.analyze

    assert_equal 3, analysis[:connected_components_count]
    assert_equal 3, analysis[:isolated_settlements_count]
    assert_operator analysis[:isolation_impact_score], :>=, 50.0
    assert_operator analysis[:network_health_score], :<=, 50.0
    assert_includes %w[DECLINING CRITICAL], analysis[:network_health_trend]
  end

  # =========================================================================
  # 3. SINGLE ROAD CLOSURE
  # =========================================================================
  test "3. single road closure removes edge, splits components, and identifies affected nodes" do
    service = Enma::NetworkConnectivityService.new(
      locations: [@guwahati, @jorhat, @shillong, @cherra],
      roads: [@road_nh27, @road_nh06, @road_sh05],
      warehouses: [@warehouse]
    )

    sim = service.simulate_road_closure(@road_sh05.id)

    assert_equal 4, sim[:pre_connected_settlements]
    assert_equal 3, sim[:post_connected_settlements]
    assert_equal 1, sim[:newly_isolated_count]
    assert_equal ["Cherrapunjee"], sim[:newly_isolated_settlements]
    assert_operator sim[:criticality_score], :>=, 40.0
    assert_includes sim[:narrative_summary], "Cherrapunjee"
  end

  # =========================================================================
  # 4. SETTLEMENT ISOLATION
  # =========================================================================
  test "4. detects isolated settlements when road is blocked with cause and previous routes" do
    @road_sh05.update!(status: "blocked")

    service = Enma::NetworkConnectivityService.new(
      locations: [@guwahati, @jorhat, @shillong, @cherra],
      roads: [@road_nh27, @road_nh06, @road_sh05],
      warehouses: [@warehouse]
    )

    analysis = service.analyze
    cherra = analysis[:isolated_settlements].find { |s| s[:name] == "Cherrapunjee" }

    assert_not_nil cherra
    assert_equal "ISOLATED", cherra[:status]
    assert_includes cherra[:cause], "blocked or impassable"
    assert_includes cherra[:previously_connected_routes], @road_sh05.name
    assert_includes cherra[:alternative_access], "emergency aerial drop required"
  end

  # =========================================================================
  # 5. WAREHOUSE DISCONNECTION
  # =========================================================================
  test "5. detects warehouse disconnection when depot node is partitioned" do
    # Create an isolated warehouse in Jorhat
    wh_jorhat = Warehouse.create!(
      name: "Jorhat Emergency Staging Depot",
      location: @jorhat,
      operational_status: "OPERATIONAL",
      readiness_score: 88.0,
      capacity: 5000,
      utilized_capacity: 1000
    )

    @road_nh27.update!(status: "blocked")

    service = Enma::NetworkConnectivityService.new(
      locations: [@guwahati, @jorhat, @shillong, @cherra],
      roads: [@road_nh27, @road_nh06, @road_sh05],
      warehouses: [@warehouse, wh_jorhat]
    )

    analysis = service.analyze
    jorhat_wh_status = analysis[:warehouses_status].find { |w| w[:id] == wh_jorhat.id }

    assert_not_nil jorhat_wh_status
    assert_equal false, jorhat_wh_status[:reachable]
    assert_equal 1, jorhat_wh_status[:component_size]
  end

  # =========================================================================
  # 6. CRITICAL CORRIDOR DETECTION (TARJAN BRIDGE)
  # =========================================================================
  test "6. detects critical roads and single points of failure (bridges) via Tarjan algorithm" do
    service = Enma::NetworkConnectivityService.new(
      locations: [@guwahati, @jorhat, @shillong, @cherra],
      roads: [@road_nh27, @road_nh06, @road_sh05],
      warehouses: [@warehouse]
    )

    analysis = service.analyze
    critical_roads = analysis[:critical_roads]

    sh05_crit = critical_roads.find { |r| r[:road_id] == @road_sh05.id }
    assert_not_nil sh05_crit
    assert_equal true, sh05_crit[:is_bridge]
    assert_operator sh05_crit[:criticality_score], :>=, 40.0
    assert_includes %w[high critical], sh05_crit[:criticality_level]
    assert_includes sh05_crit[:explanation], "Tarjan Bridge"
  end

  # =========================================================================
  # 7. ALTERNATIVE ROUTE AVAILABILITY (DIJKSTRA)
  # =========================================================================
  test "7. identifies alternative reachable warehouse or reports when no alternative route is available" do
    service = Enma::NetworkConnectivityService.new(
      locations: [@guwahati, @jorhat, @shillong, @cherra],
      roads: [@road_nh27, @road_nh06, @road_sh05],
      warehouses: [@warehouse]
    )

    analysis = service.analyze
    cherra_analysis = analysis[:all_settlements].find { |s| s[:name] == "Cherrapunjee" }

    # Initially connected: can reach Guwahati Central Depot
    assert_not_nil cherra_analysis[:alternative_warehouse]
    assert_equal "Guwahati Central Depot", cherra_analysis[:alternative_warehouse][:warehouse_name]
    assert_in_delta(155.0, cherra_analysis[:alternative_warehouse][:distance_km], 50.0)

    # Now block SH-05
    @road_sh05.update!(status: "blocked")
    service_blocked = Enma::NetworkConnectivityService.new(
      locations: [@guwahati, @jorhat, @shillong, @cherra],
      roads: [@road_nh27, @road_nh06, @road_sh05],
      warehouses: [@warehouse]
    )
    analysis_blocked = service_blocked.analyze
    cherra_blocked = analysis_blocked[:all_settlements].find { |s| s[:name] == "Cherrapunjee" }

    # When blocked, no alternative warehouse is reachable
    assert_nil cherra_blocked[:alternative_warehouse]
    assert_includes cherra_blocked[:recommended_action], "aerial supply drop"
  end

  # =========================================================================
  # 8. EMPTY NETWORK
  # =========================================================================
  test "8. handles empty network without errors and returns 100% health score" do
    service = Enma::NetworkConnectivityService.new(
      locations: [],
      roads: [],
      warehouses: []
    )

    analysis = service.analyze

    assert_equal 100.0, analysis[:network_health_score]
    assert_equal 0.0, analysis[:isolation_impact_score]
    assert_equal 0, analysis[:total_settlements]
    assert_equal 0, analysis[:connected_settlements_count]
    assert_equal 0, analysis[:isolated_settlements_count]
    assert_equal [], analysis[:components]
    assert_equal "STABLE", analysis[:network_health_trend]
  end

  # =========================================================================
  # 9. NETWORK HEALTH CALCULATION & TREND
  # =========================================================================
  test "9. calculates network health score, active disruptions, and dynamic trend" do
    service = Enma::NetworkConnectivityService.new(
      locations: [@guwahati, @jorhat, @shillong, @cherra],
      roads: [@road_nh27, @road_nh06, @road_sh05],
      warehouses: [@warehouse]
    )

    analysis = service.analyze
    assert_equal 100.0, analysis[:network_health_score]
    assert_equal "STABLE", analysis[:network_health_trend]

    # Block 1 road
    @road_nh27.update!(status: "blocked")
    service_degraded = Enma::NetworkConnectivityService.new(
      locations: [@guwahati, @jorhat, @shillong, @cherra],
      roads: [@road_nh27, @road_nh06, @road_sh05],
      warehouses: [@warehouse]
    )
    degraded_analysis = service_degraded.analyze
    assert_operator degraded_analysis[:network_health_score], :<, 100.0
    assert_equal 1, degraded_analysis[:blocked_roads_count]
    assert_includes %w[DECLINING CRITICAL], degraded_analysis[:network_health_trend]
  end

  test "generates deduplicated LogisticsAlert records for isolated settlements and critical blocked corridors" do
    @road_sh05.update!(status: "blocked", risk_score: 95.0)

    service = Enma::NetworkConnectivityService.new(
      locations: [@guwahati, @jorhat, @shillong, @cherra],
      roads: [@road_nh27, @road_nh06, @road_sh05],
      warehouses: [@warehouse]
    )

    alerts = service.generate_connectivity_alerts!
    assert_operator alerts.size, :>=, 1

    # Check alert attributes
    iso_alert = alerts.find { |a| a.alert_type == "settlement_isolated" }
    assert_not_nil iso_alert
    assert_equal "Cherrapunjee", iso_alert.location_name
    assert_equal "critical", iso_alert.severity
    assert_not_nil iso_alert.dedup_key

    # Re-running generation should deduplicate
    repeat_alerts = service.generate_connectivity_alerts!
    assert_empty repeat_alerts
  end

  test "generates warehouse_isolated alert when depot node is partitioned" do
    wh_jorhat = Warehouse.create!(
      name: "Jorhat Relief Hub",
      location: @jorhat,
      operational_status: "OPERATIONAL",
      readiness_score: 90.0
    )

    @road_nh27.update!(status: "blocked")

    service = Enma::NetworkConnectivityService.new(
      locations: [@guwahati, @jorhat, @shillong, @cherra],
      roads: [@road_nh27, @road_nh06, @road_sh05],
      warehouses: [@warehouse, wh_jorhat]
    )

    alerts = service.generate_connectivity_alerts!
    wh_alert = alerts.find { |a| a.alert_type == "warehouse_isolated" }
    assert_not_nil wh_alert
    assert_equal "Jorhat Relief Hub", wh_alert.location_name
  end
end
