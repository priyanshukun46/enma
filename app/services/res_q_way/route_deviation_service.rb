module ResQWay
  class RouteDeviationService
    EARTH_RADIUS_KM = 6371.0
    DEFAULT_THRESHOLD_METERS = 800.0 # Configurable deviation threshold

    attr_reader :shipment, :current_lat, :current_lon, :threshold_meters

    def initialize(shipment:, current_lat:, current_lon:, threshold_meters: DEFAULT_THRESHOLD_METERS)
      @shipment = shipment
      @current_lat = current_lat.to_f
      @current_lon = current_lon.to_f
      @threshold_meters = threshold_meters.to_f
    end

    def evaluate
      geometry = shipment.planned_geometry
      return { deviation_detected: false, deviation_distance_meters: 0.0 } if geometry.blank? || geometry.size < 2

      # Find minimum distance to any route segment
      min_dist_km = Float::INFINITY

      geometry.each_cons(2) do |p1, p2|
        d_km = distance_to_segment(
          current_lat, current_lon,
          p1[0].to_f, p1[1].to_f,
          p2[0].to_f, p2[1].to_f
        )
        min_dist_km = [min_dist_km, d_km].min
      end

      min_dist_meters = (min_dist_km * 1000.0).round(1)
      deviation_detected = min_dist_meters > threshold_meters

      {
        deviation_detected: deviation_detected,
        deviation_distance_meters: min_dist_meters,
        threshold_meters: threshold_meters,
        message: deviation_detected ? "Vehicle deviated #{min_dist_meters}m from planned corridor (Allowed: #{threshold_meters}m)" : "Vehicle on corridor track"
      }
    end

    private

    # Perpendicular distance from point P to line segment AB
    def distance_to_segment(plat, plon, alat, alon, blat, blon)
      # Project lat/lon to local Cartesian for small segment approximation
      dx = (blon - alon) * Math.cos((alat + blat) * Math::PI / 360.0)
      dy = blat - alat
      len_sq = dx * dx + dy * dy

      if len_sq.zero?
        return haversine(plat, plon, alat, alon)
      end

      # Projection factor t
      px = (plon - alon) * Math.cos((alat + blat) * Math::PI / 360.0)
      py = plat - alat
      t = [(px * dx + py * dy) / len_sq, 0.0].max
      t = [t, 1.0].min

      proj_lat = alat + t * dy
      proj_lon = alon + t * (dx / Math.cos((alat + blat) * Math::PI / 360.0))

      haversine(plat, plon, proj_lat, proj_lon)
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
