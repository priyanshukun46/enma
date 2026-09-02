require "net/http"
require "json"
require "uri"

module Routing
  class OsrmProvider < BaseProvider
    DEFAULT_BASE_URL = "https://router.project-osrm.org".freeze

    def calculate_routes(origin, destination, alternatives: true)
      lat1, lon1 = extract_lat_lon(origin)
      lat2, lon2 = extract_lat_lon(destination)

      base_url = ENV["OSRM_API_URL"].presence || DEFAULT_BASE_URL
      alt_param = alternatives ? "alternatives=3&" : ""
      url_str = "#{base_url.chomp('/')}/route/v1/driving/#{lon1},#{lat1};#{lon2},#{lat2}?overview=full&geometries=geojson&steps=true&#{alt_param}"

      uri = URI.parse(url_str)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = options[:timeout] || DEFAULT_TIMEOUT
      http.read_timeout = options[:timeout] || DEFAULT_TIMEOUT

      request = Net::HTTP::Get.new(uri.request_uri)
      request["User-Agent"] = "ENMA-AI-Routing-Engine/2.0"

      response = http.request(request)
      return nil unless response.is_a?(Net::HTTPSuccess)

      data = JSON.parse(response.body)
      return nil unless data["code"] == "Ok" && data["routes"].is_a?(Array) && data["routes"].any?

      parse_routes(data["routes"])
    rescue StandardError => e
      Rails.logger.warn("[Routing::OsrmProvider] Error querying OSRM: #{e.message}")
      nil
    end

    private

    def parse_routes(osrm_routes)
      osrm_routes.map.with_index do |route_data, idx|
        raw_coords = route_data.dig("geometry", "coordinates") || []
        coords = raw_coords.map { |point| [point[1].to_f.round(5), point[0].to_f.round(5)] }

        dist_km = (route_data["distance"].to_f / 1000.0).round(1)
        duration_secs = route_data["duration"].to_f
        duration_mins = (duration_secs / 60.0).round
        duration_hrs = (duration_secs / 3600.0).round(2)

        steps = extract_steps(route_data)
        summary = route_data["legs"]&.first&.dig("summary").presence || "National Highway Corridor"

        {
          id: "route_#{idx + 1}",
          index: idx,
          name: summary,
          distance_km: dist_km,
          duration_minutes: duration_mins,
          estimated_hours: duration_hrs,
          geometry: coords,
          coordinates: coords,
          steps: steps,
          source: "osrm",
          fallback_used: false,
          summary: summary
        }
      end
    end

    def extract_steps(route_data)
      legs = route_data["legs"] || []
      return [] if legs.empty?

      raw_steps = legs.first["steps"] || []
      raw_steps.map.with_index do |st, s_idx|
        maneuver = st["maneuver"] || {}
        instruction_text = format_step_instruction(maneuver, st["name"])

        {
          step_number: s_idx + 1,
          instruction: instruction_text,
          maneuver_type: maneuver["type"].to_s,
          modifier: maneuver["modifier"].to_s,
          road_name: st["name"].presence || "Connecting Road",
          distance_m: st["distance"].to_f.round,
          distance_km: (st["distance"].to_f / 1000.0).round(2),
          duration_s: st["duration"].to_f.round,
          location: maneuver["location"] ? [maneuver["location"][1].to_f.round(5), maneuver["location"][0].to_f.round(5)] : nil
        }
      end
    end

    def format_step_instruction(maneuver, road_name)
      type = maneuver["type"].to_s
      modifier = maneuver["modifier"].to_s
      name = road_name.presence || "highway"

      case type
      when "depart"
        "Depart and head #{modifier.presence || 'forward'} on #{name}"
      when "arrive"
        "Arrive at destination on #{name}"
      when "turn"
        "Turn #{modifier.presence || 'onto'} #{name}"
      when "fork"
        "Take #{modifier.presence || 'side'} fork onto #{name}"
      when "roundabout"
        "Enter roundabout and take exit onto #{name}"
      when "merge"
        "Merge #{modifier.presence || ''} onto #{name}"
      else
        modifier.present? ? "#{type.titleize} #{modifier} onto #{name}" : "Continue on #{name}"
      end
    end
  end
end
