module Routing
  class FallbackProvider < BaseProvider
    def calculate_routes(origin, destination, alternatives: true)
      lat1, lon1 = extract_lat_lon(origin)
      lat2, lon2 = extract_lat_lon(destination)

      haversine_dist = haversine_distance(lat1, lon1, lat2, lon2)

      variants = [
        { id: "route_1", type_name: "Direct Arterial (NH Track)", circuity: 1.30, curve_offset: 0.03, speed: 52.0 },
        { id: "route_2", type_name: "Highland Bypass (Ridge Corridor)", circuity: 1.52, curve_offset: 0.16, speed: 44.0 },
        { id: "route_3", type_name: "Valley Transit (River Basin Track)", circuity: 1.40, curve_offset: -0.10, speed: 48.0 }
      ]

      variants.map.with_index do |v, idx|
        dist_km = (haversine_dist * v[:circuity]).round(1)
        duration_hrs = (dist_km / v[:speed]).round(2)
        duration_mins = (duration_hrs * 60).round

        coords = generate_curved_waypoints(lat1, lon1, lat2, lon2, v[:curve_offset])
        steps = generate_fallback_steps(coords, dist_km, duration_mins)

        {
          id: v[:id],
          index: idx,
          name: v[:type_name],
          distance_km: dist_km,
          duration_minutes: duration_mins,
          estimated_hours: duration_hrs,
          geometry: coords,
          coordinates: coords,
          steps: steps,
          source: "fallback_terrain_model",
          fallback_used: true,
          summary: "#{v[:type_name]} (Terrain-modeled corridor)"
        }
      end
    end

    private

    def generate_curved_waypoints(lat1, lon1, lat2, lon2, curve_offset)
      steps = 12
      points = []
      points << [lat1.round(5), lon1.round(5)]

      dx = lat2 - lat1
      dy = lon2 - lon1
      len = Math.sqrt(dx * dx + dy * dy)
      norm_x = len.zero? ? 0 : -dy / len
      norm_y = len.zero? ? 0 : dx / len

      (1...steps).each do |i|
        t = i.to_f / steps
        base_lat = lat1 + dx * t
        base_lon = lon1 + dy * t

        sine_offset = Math.sin(t * Math::PI) * curve_offset + Math.sin(t * 3 * Math::PI) * (curve_offset * 0.25)
        curved_lat = base_lat + (norm_x * sine_offset)
        curved_lon = base_lon + (norm_y * sine_offset)

        points << [curved_lat.round(5), curved_lon.round(5)]
      end

      points << [lat2.round(5), lon2.round(5)]
      points
    end

    def generate_fallback_steps(coords, total_dist_km, total_mins)
      return [] if coords.size < 2

      step_dist = (total_dist_km / (coords.size - 1)).round(1)
      step_duration = ((total_mins.to_f / (coords.size - 1)) * 60).round

      coords.each_cons(2).with_index.map do |(p1, p2), s_idx|
        if s_idx == 0
          {
            step_number: 1,
            instruction: "Depart origin and proceed onto regional logistics highway",
            maneuver_type: "depart",
            modifier: "straight",
            road_name: "National Highway Sector",
            distance_m: (step_dist * 1000).round,
            distance_km: step_dist,
            duration_s: step_duration,
            location: p1
          }
        elsif s_idx == coords.size - 2
          {
            step_number: s_idx + 1,
            instruction: "Continue straight and arrive at destination terminal",
            maneuver_type: "arrive",
            modifier: "straight",
            road_name: "Terminal Access Road",
            distance_m: (step_dist * 1000).round,
            distance_km: step_dist,
            duration_s: step_duration,
            location: p2
          }
        else
          turn_type = (s_idx % 2 == 0) ? "slight right" : "slight left"
          {
            step_number: s_idx + 1,
            instruction: "Follow highway #{turn_type} along mountain pass corridor",
            maneuver_type: "turn",
            modifier: turn_type,
            road_name: "Highland Arterial Segment #{s_idx}",
            distance_m: (step_dist * 1000).round,
            distance_km: step_dist,
            duration_s: step_duration,
            location: p1
          }
        end
      end
    end
  end
end
