module Routing
  class BaseProvider
    EARTH_RADIUS_KM = 6371.0
    DEFAULT_TIMEOUT = 2.5

    attr_reader :options

    def initialize(options = {})
      @options = options
    end

    def calculate_routes(origin, destination, alternatives: true)
      raise NotImplementedError, "#{self.class.name}#calculate_routes must be implemented"
    end

    protected

    def extract_lat_lon(loc)
      if loc.respond_to?(:latitude) && loc.respond_to?(:longitude)
        [loc.latitude.to_f, loc.longitude.to_f]
      elsif loc.is_a?(Array) && loc.size >= 2
        [loc[0].to_f, loc[1].to_f]
      elsif loc.is_a?(Hash)
        [loc[:latitude] || loc["latitude"] || loc[:lat] || loc["lat"],
         loc[:longitude] || loc["longitude"] || loc[:lon] || loc["lon"]]
      else
        [0.0, 0.0]
      end
    end

    def haversine_distance(lat1, lon1, lat2, lon2)
      return 0.0 if lat1.nil? || lon1.nil? || lat2.nil? || lon2.nil?

      dlat_rad = (lat2 - lat1) * Math::PI / 180.0
      dlon_rad = (lon2 - lon1) * Math::PI / 180.0
      lat1_rad = lat1 * Math::PI / 180.0
      lat2_rad = lat2 * Math::PI / 180.0

      a = (Math.sin(dlat_rad / 2.0)**2) +
          (Math.cos(lat1_rad) * Math.cos(lat2_rad) * (Math.sin(dlon_rad / 2.0)**2))
      c = 2.0 * Math.atan2(Math.sqrt(a), Math.sqrt(1.0 - a))
      EARTH_RADIUS_KM * c
    end
  end
end
