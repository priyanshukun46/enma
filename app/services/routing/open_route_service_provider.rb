require "net/http"
require "json"
require "uri"

module Routing
  class OpenRouteServiceProvider < BaseProvider
    DEFAULT_BASE_URL = "https://api.openrouteservice.org/v2/directions/driving-car".freeze

    def calculate_routes(origin, destination, alternatives: true)
      api_key = ENV["ROUTING_API_KEY"] || ENV["ORS_API_KEY"]
      return nil if api_key.blank?

      lat1, lon1 = extract_lat_lon(origin)
      lat2, lon2 = extract_lat_lon(destination)

      base_url = ENV["OPENROUTESERVICE_URL"].presence || DEFAULT_BASE_URL
      uri = URI.parse(base_url)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = options[:timeout] || DEFAULT_TIMEOUT
      http.read_timeout = options[:timeout] || DEFAULT_TIMEOUT

      request = Net::HTTP::Post.new(uri.request_uri, {
        "Content-Type" => "application/json",
        "Authorization" => api_key
      })

      body_params = {
        coordinates: [[lon1, lat1], [lon2, lat2]],
        instructions: true,
        alternative_routes: alternatives ? { target_count: 3 } : nil
      }.compact

      request.body = body_params.to_json
      response = http.request(request)

      return nil unless response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)

      parse_ors_routes(data["routes"] || [])
    rescue StandardError => e
      Rails.logger.warn("[Routing::OpenRouteServiceProvider] Error: #{e.message}")
      nil
    end

    private

    def parse_ors_routes(routes)
      routes.map.with_index do |r, idx|
        summary = r["summary"] || {}
        dist_km = (summary["distance"].to_f / 1000.0).round(1)
        dur_secs = summary["duration"].to_f
        dur_mins = (dur_secs / 60.0).round
        dur_hrs = (dur_secs / 3600.0).round(2)

        raw_geom = r["geometry"] # Polyline or GeoJSON
        coords = []
        if raw_geom.is_a?(Hash) && raw_geom["coordinates"]
          coords = raw_geom["coordinates"].map { |pt| [pt[1].to_f.round(5), pt[0].to_f.round(5)] }
        end

        {
          id: "route_#{idx + 1}",
          index: idx,
          name: "ORS Corridor #{idx + 1}",
          distance_km: dist_km,
          duration_minutes: dur_mins,
          estimated_hours: dur_hrs,
          geometry: coords,
          coordinates: coords,
          steps: [],
          source: "openrouteservice",
          fallback_used: false,
          summary: "OpenRouteService Highway Track"
        }
      end
    end
  end
end
