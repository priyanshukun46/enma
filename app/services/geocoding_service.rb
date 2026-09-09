require "net/http"
require "json"
require "uri"

class GeocodingService
  BASE_URL = "https://nominatim.openstreetmap.org/search".freeze
  TIMEOUT_SECONDS = 2.0
  CACHE_EXPIRATION = 24.hours

  attr_reader :query

  def initialize(query)
    @query = query.to_s.strip
  end

  def self.search(query, force_refresh: false)
    new(query).search(force_refresh: force_refresh)
  end

  def search(force_refresh: false)
    return nil if query.blank?

    # 1. Check local database first for instant 0ms matching
    db_location = Location.where("LOWER(name) = ?", query.downcase).first
    if db_location.present? && db_location.latitude.present? && db_location.longitude.present?
      return {
        name: db_location.name,
        latitude: db_location.latitude.to_f,
        longitude: db_location.longitude.to_f,
        display_name: "#{db_location.name}, #{db_location.district}, #{db_location.state}",
        source: "db_match"
      }
    end

    # 2. Check Rails Cache
    cache_key = "resqway_geocode_v1_#{query.parameterize}"
    if force_refresh
      Rails.cache.delete(cache_key)
    else
      cached = Rails.cache.read(cache_key)
      return cached if cached.present?
    end

    # 3. Query OpenStreetMap Nominatim API
    result = fetch_from_nominatim
    if result.present?
      Rails.cache.write(cache_key, result, expires_in: CACHE_EXPIRATION)
      result
    else
      fallback_geocoding
    end
  rescue StandardError => e
    Rails.logger.warn("[GeocodingService] Lookup failed for '#{query}': #{e.message}. Using fallback.")
    fallback_geocoding
  end

  private

  def fetch_from_nominatim
    uri = URI(BASE_URL)
    params = {
      q: query,
      format: "json",
      limit: 1,
      addressdetails: 1
    }
    uri.query = URI.encode_www_form(params)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.open_timeout = TIMEOUT_SECONDS
    http.read_timeout = TIMEOUT_SECONDS

    request = Net::HTTP::Get.new(uri.request_uri)
    request["User-Agent"] = "ResQWay-Logistics/2.0 (Predictive Logistics Intelligence)"

    response = http.request(request)
    return nil unless response.is_a?(Net::HTTPSuccess)

    parsed = JSON.parse(response.body)
    return nil unless parsed.is_a?(Array) && parsed.any?

    first = parsed.first
    lat = first["lat"]&.to_f
    lon = first["lon"]&.to_f

    return nil if lat.nil? || lon.nil? || (lat.zero? && lon.zero?)

    {
      name: first["name"].presence || query,
      latitude: lat.round(5),
      longitude: lon.round(5),
      display_name: first["display_name"].presence || query,
      source: "live"
    }
  end

  def fallback_geocoding
    # 1. Try full partial match
    match = Location.where("LOWER(name) LIKE ?", "%#{query.downcase}%").first

    # 2. If no full match, try matching by individual tokens/words
    if match.nil?
      tokens = query.downcase.split(/\W+/).reject { |t| %w[city town district area near].include?(t) }
      tokens.each do |token|
        match = Location.where("LOWER(name) LIKE ?", "%#{token}%").first
        break if match.present?
      end
    end

    if match.present? && match.latitude.present? && match.longitude.present?
      {
        name: match.name,
        latitude: match.latitude.to_f,
        longitude: match.longitude.to_f,
        display_name: "#{match.name}, #{match.state}",
        source: "demo_fallback"
      }
    else
      nil
    end
  end
end
