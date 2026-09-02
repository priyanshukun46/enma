module Enma
  class DeliveryProgressService
    EARTH_RADIUS_KM = 6371.0

    attr_reader :shipment, :current_lat, :current_lon

    def initialize(shipment:, current_lat:, current_lon:)
      @shipment = shipment
      @current_lat = current_lat.to_f
      @current_lon = current_lon.to_f
    end

    def calculate
      return fallback_progress if current_lat.zero? || current_lon.zero?

      geometry = shipment.planned_geometry
      if geometry.present? && geometry.size >= 2
        calculate_route_progress(geometry)
      else
        fallback_progress
      end
    end

    private

    def calculate_route_progress(geometry)
      # Find the closest point index on the planned route
      min_dist = Float::INFINITY
      closest_index = 0

      geometry.each_with_index do |pt, idx|
        dist = haversine(current_lat, current_lon, pt[0].to_f, pt[1].to_f)
        if dist < min_dist
          min_dist = dist
          closest_index = idx
        end
      end

      # Calculate cumulative distance up to closest point
      traveled_km = 0.0
      (0...closest_index).each do |i|
        p1 = geometry[i]
        p2 = geometry[i + 1]
        traveled_km += haversine(p1[0].to_f, p1[1].to_f, p2[0].to_f, p2[1].to_f)
      end

      total_km = shipment.total_distance_km.presence || calculate_total_geometry_distance(geometry)
      total_km = [total_km.to_f, 1.0].max

      progress_pct = ((traveled_km / total_km) * 100.0).clamp(0.0, 100.0).round(1)

      {
        progress_percentage: progress_pct,
        distance_traveled_km: traveled_km.round(1),
        remaining_distance_km: [(total_km - traveled_km), 0.0].max.round(1),
        total_distance_km: total_km.round(1),
        closest_waypoint_index: closest_index,
        calculation_method: "route_geometry_projection"
      }
    end

    def fallback_progress
      # Haversine distance between origin and destination
      orig_lat = shipment.origin_latitude || shipment.origin&.latitude || 26.14
      orig_lon = shipment.origin_longitude || shipment.origin&.longitude || 91.73
      dest_lat = shipment.destination_latitude || shipment.destination&.latitude || 25.57
      dest_lon = shipment.destination_longitude || shipment.destination&.longitude || 91.89

      total_dist = haversine(orig_lat, orig_lon, dest_lat, dest_lon) * 1.3
      total_dist = [total_dist, 1.0].max

      dist_from_origin = haversine(orig_lat, orig_lon, current_lat, current_lon)
      dist_to_dest = haversine(current_lat, current_lon, dest_lat, dest_lon)

      progress_pct = ((dist_from_origin / (dist_from_origin + dist_to_dest)) * 100.0).clamp(0.0, 100.0).round(1)

      {
        progress_percentage: progress_pct,
        distance_traveled_km: [dist_from_origin.round(1), total_dist.round(1)].min,
        remaining_distance_km: dist_to_dest.round(1),
        total_distance_km: total_dist.round(1),
        calculation_method: "haversine_approximation"
      }
    end

    def calculate_total_geometry_distance(geometry)
      total = 0.0
      geometry.each_cons(2) do |p1, p2|
        total += haversine(p1[0].to_f, p1[1].to_f, p2[0].to_f, p2[1].to_f)
      end
      total
    end

    def haversine(lat1, lon1, lat2, lon2)
      return 0.0 if lat1.nil? || lon1.nil? || lat2.nil? || lon2.nil?
      dlat = (lat2 - lat1) * Math::PI / 180.0
      dlon = (lon2 - lon1) * Math::PI / 180.0
      a = Math.sin(dlat / 2.0)**2 + Math.cos(lat1 * Math::PI / 180.0) * Math.cos(lat2 * Math::PI / 180.0) * Math.sin(dlon / 2.0)**2
      c = 2.0 * Math.atan2(Math.sqrt(a), Math.sqrt(1.0 - a))
      EARTH_RADIUS_KM * c
    end
  end
end
