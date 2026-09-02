module Routing
  class RoutingProvider
    @@route_cache = {}

    def self.calculate_routes(origin, destination, options = {})
      new(options).calculate_routes(origin, destination)
    end

    attr_reader :options, :preferred_provider_name

    def initialize(options = {})
      @options = options
      @preferred_provider_name = (options[:provider] || ENV["ROUTING_PROVIDER"] || "osrm").to_s.downcase
    end

    def calculate_routes(origin, destination)
      key = cache_key_for(origin, destination)
      return @@route_cache[key] if !Rails.env.test? && @@route_cache.key?(key)

      cached = Rails.cache.read(key)
      if cached.present?
        @@route_cache[key] = cached
        return cached
      end

      provider = build_provider(preferred_provider_name)
      routes = provider.calculate_routes(origin, destination, alternatives: true)

      if routes.blank? || routes.empty?
        routes = FallbackProvider.new(options).calculate_routes(origin, destination, alternatives: true)
      end

      if routes.present? && routes.any?
        @@route_cache[key] = routes
        Rails.cache.write(key, routes, expires_in: 24.hours)
      end

      routes
    rescue StandardError => e
      Rails.logger.warn("[RoutingProvider] Routing error: #{e.message}. Using FallbackProvider.")
      fallback = FallbackProvider.new(options).calculate_routes(origin, destination, alternatives: true)
      @@route_cache[key] = fallback if key
      fallback
    end

    private

    def cache_key_for(origin, destination)
      lat1 = origin.respond_to?(:latitude) ? origin.latitude.to_f.round(3) : origin[0].to_f.round(3)
      lon1 = origin.respond_to?(:longitude) ? origin.longitude.to_f.round(3) : origin[1].to_f.round(3)
      lat2 = destination.respond_to?(:latitude) ? destination.latitude.to_f.round(3) : destination[0].to_f.round(3)
      lon2 = destination.respond_to?(:longitude) ? destination.longitude.to_f.round(3) : destination[1].to_f.round(3)
      "routing_v3_#{lat1}_#{lon1}_#{lat2}_#{lon2}_#{preferred_provider_name}"
    end

    def build_provider(name)
      case name
      when "openrouteservice", "ors"
        OpenRouteServiceProvider.new(options)
      when "fallback"
        FallbackProvider.new(options)
      else
        OsrmProvider.new(options.reverse_merge(timeout: 0.6))
      end
    end
  end
end
