# frozen_string_literal: true

class NetworkController < ApplicationController
  def index
    @simulated_road_ids = Array(params[:simulated_road_id]).compact_blank.map(&:to_i)
    @service = ResQWay::NetworkConnectivityService.new
    @network_data = @service.analyze(simulated_road_ids: @simulated_road_ids)

    @simulation_result = if @simulated_road_ids.any?
                           @service.simulate_road_closure(@simulated_road_ids)
                         end

    @roads = Road.order(:road_number)
    @connectivity_alerts = LogisticsAlert.where(
      alert_type: %w[settlement_isolated warehouse_isolated critical_corridor_blocked network_connectivity_drop]
    ).active.recent.limit(8)

    # Graph JSON payload for Leaflet visualization
    @graph_json = {
      nodes: @service.nodes.values.map(&:as_json),
      edges: @service.edges.map(&:as_json),
      isolated_node_ids: @network_data[:isolated_settlements].map { |s| s[:id] },
      critical_road_ids: @network_data[:critical_roads].select { |r| r[:criticality_score] >= 50.0 }.map { |r| r[:road_id] },
      bridge_road_ids: @network_data[:critical_roads].select { |r| r[:is_bridge] }.map { |r| r[:road_id] },
      simulated_closed_ids: @simulated_road_ids
    }

    respond_to do |format|
      format.html
      format.json { render json: @network_data.merge(graph: @graph_json, simulation: @simulation_result) }
    end
  end

  def simulate
    road_ids = Array(params[:road_id]).compact_blank.map(&:to_i)
    service = ResQWay::NetworkConnectivityService.new
    @simulation_result = service.simulate_road_closure(road_ids)

    respond_to do |format|
      format.html do
        redirect_to network_path(simulated_road_id: road_ids.first), notice: "Simulated closure analysis generated."
      end
      format.json { render json: @simulation_result }
    end
  end
end
