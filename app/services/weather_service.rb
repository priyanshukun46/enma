require "net/http"
require "json"
require "uri"

class WeatherService
  BASE_URL = "https://api.open-meteo.com/v1/forecast".freeze
  TIMEOUT_SECONDS = 0.8
  CACHE_EXPIRATION = 30.minutes

  @@memory_cache = {}

  WMO_CODES = {
    0 => "Clear Sky",
    1 => "Mainly Clear",
    2 => "Partly Cloudy",
    3 => "Overcast",
    45 => "Foggy",
    48 => "Depositing Rime Fog",
    51 => "Light Drizzle",
    53 => "Moderate Drizzle",
    55 => "Dense Drizzle",
    61 => "Slight Rain",
    63 => "Moderate Rain",
    65 => "Heavy Monsoon Rain",
    71 => "Slight Snow",
    73 => "Moderate Snow",
    75 => "Heavy Snow",
    77 => "Snow Grains",
    80 => "Slight Rain Showers",
    81 => "Moderate Rain Showers",
    82 => "Violent Rain Showers / Cloudburst",
    85 => "Slight Snow Showers",
    86 => "Heavy Snow Showers",
    95 => "Thunderstorm",
    96 => "Thunderstorm with Slight Hail",
    99 => "Severe Thunderstorm with Heavy Hail"
  }.freeze

  attr_reader :latitude, :longitude, :fallback_location

  def initialize(latitude:, longitude:, fallback_location: nil)
    @latitude = latitude&.to_f
    @longitude = longitude&.to_f
    @fallback_location = fallback_location
  end

  def self.fetch(latitude, longitude, fallback_location: nil, force_refresh: false)
    new(
      latitude: latitude,
      longitude: longitude,
      fallback_location: fallback_location
    ).fetch(force_refresh: force_refresh)
  end

  def self.sample_corridor_weather(coordinates, fallback_location: nil)
    coords = Array(coordinates)
    return fallback_corridor_weather(fallback_location) if coords.empty?

    # Sample 3 representative points (origin, midpoint, destination) to balance GIS fidelity and speed
    sample_indices = if coords.size <= 3
                       (0...coords.size).to_a
                     else
                       [0, (coords.size / 2).round, coords.size - 1].uniq
                     end

    samples = sample_indices.map do |idx|
      pt = coords[idx]
      fetch(pt[0], pt[1], fallback_location: fallback_location)
    end

    max_precip = samples.map { |s| s[:precipitation].to_f }.max || 0.0
    max_wind = samples.map { |s| s[:wind_speed].to_f }.max || 0.0
    avg_temp = (samples.map { |s| s[:temperature].to_f }.sum / [samples.size, 1].max).round(1)
    severe_codes = samples.map { |s| s[:weather_code].to_i }.select { |c| [81, 82, 95, 96, 99].include?(c) }

    # Weather Exposure Score (0 - 100): 60% Rain, 25% Wind, 15% Severe WMO events
    rain_part = [(max_precip / 40.0) * 60.0, 60.0].min
    wind_part = [(max_wind / 60.0) * 25.0, 25.0].min
    severe_part = severe_codes.any? ? 15.0 : 0.0
    exposure_score = (rain_part + wind_part + severe_part).clamp(0.0, 100.0).round(1)

    all_sources = samples.map { |s| s[:source] }
    source = if all_sources.all? { |src| src == "demo_fallback" }
               "demo_fallback"
             elsif all_sources.any? { |src| src == "cached_live" }
               "cached_live"
             else
               "live"
             end

    condition_summary = if severe_codes.any?
                          "Severe Weather Alert along Corridor"
                        elsif max_precip >= 10.0
                          "Heavy Rainfall Exposure (#{max_precip.round(1)} mm/hr)"
                        elsif max_precip >= 2.5
                          "Moderate Rain Exposure (#{max_precip.round(1)} mm/hr)"
                        else
                          "Nominal Dry Weather"
                        end

    {
      samples_count: samples.size,
      max_precipitation_mm: max_precip.round(1),
      max_wind_kmh: max_wind.round(1),
      average_temperature_c: avg_temp,
      weather_exposure_score: exposure_score,
      severe_conditions: severe_codes.any?,
      condition_summary: condition_summary,
      source: source,
      samples: samples
    }
  end

  def self.fallback_corridor_weather(fallback_location)
    fb = new(latitude: nil, longitude: nil, fallback_location: fallback_location).send(:fallback_data)
    {
      samples_count: 1,
      max_precipitation_mm: fb[:precipitation],
      max_wind_kmh: fb[:wind_speed],
      average_temperature_c: fb[:temperature],
      weather_exposure_score: fb[:rainfall_level] == "extreme" ? 75.0 : (fb[:rainfall_level] == "high" ? 45.0 : 15.0),
      severe_conditions: fb[:rainfall_level] == "extreme",
      condition_summary: fb[:condition_text],
      source: "demo_fallback",
      samples: [fb]
    }
  end

  def fetch(force_refresh: false)
    return fallback_data if latitude.blank? || longitude.blank?

    cache_key = "resqway_weather_v1_#{latitude.round(3)}_#{longitude.round(3)}"

    # In-memory instant cache check
    if !force_refresh && @@memory_cache[cache_key].present?
      cached_item = @@memory_cache[cache_key]
      if cached_item[:cached_at] && cached_item[:cached_at] > 30.minutes.ago
        d = cached_item[:data]
        return d[:source] == "live" ? d.merge(source: "cached_live") : d
      end
    end

    if force_refresh
      Rails.cache.delete(cache_key)
      @@memory_cache.delete(cache_key)
    else
      cached = Rails.cache.read(cache_key)
      if cached.present?
        data = cached[:source] == "live" ? cached.merge(source: "cached_live") : cached
        @@memory_cache[cache_key] = { data: data, cached_at: Time.current }
        return data
      end
    end

    data = fetch_from_api
    Rails.cache.write(cache_key, data, expires_in: CACHE_EXPIRATION)
    @@memory_cache[cache_key] = { data: data, cached_at: Time.current }
    data
  rescue StandardError => e
    Rails.logger.warn("[WeatherService] API error for (#{latitude}, #{longitude}): #{e.message}. Using demo fallback.")
    fallback_data
  end

  private

  def fetch_from_api
    return fallback_data if Rails.env.test?

    uri = URI(BASE_URL)
    params = {
      latitude: latitude,
      longitude: longitude,
      current: "temperature_2m,relative_humidity_2m,precipitation,rain,weather_code,wind_speed_10m",
      timezone: "auto"
    }
    uri.query = URI.encode_www_form(params)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.open_timeout = TIMEOUT_SECONDS
    http.read_timeout = TIMEOUT_SECONDS

    request = Net::HTTP::Get.new(uri.request_uri)
    request["User-Agent"] = "ResQWay-Logistics/1.0 (Logistics Weather Platform)"

    response = http.request(request)

    if response.is_a?(Net::HTTPSuccess)
      parse_weather_response(JSON.parse(response.body))
    else
      Rails.logger.warn("[WeatherService] Non-success HTTP #{response.code}: #{response.body}")
      fallback_data
    end
  end

  def parse_weather_response(json)
    current = json["current"] || {}
    temp = current["temperature_2m"]&.to_f
    precip = current["precipitation"]&.to_f || current["rain"]&.to_f || 0.0
    rain = current["rain"]&.to_f || precip
    wind = current["wind_speed_10m"]&.to_f || 0.0
    code = current["weather_code"]&.to_i || 0
    humidity = current["relative_humidity_2m"]&.to_f || 65.0

    condition = WMO_CODES.fetch(code, "Clear")
    level = derive_rainfall_level(precip, code)

    {
      temperature: temp,
      precipitation: precip,
      rainfall: rain,
      wind_speed: wind,
      weather_code: code,
      condition_text: condition,
      rainfall_level: level,
      humidity: humidity,
      fetched_at: Time.current,
      source: "live"
    }
  end

  def derive_rainfall_level(precipitation_mm, weather_code)
    # Severe cloudburst or violent thunderstorm
    if precipitation_mm >= 30.0 || [82, 95, 96, 99].include?(weather_code)
      "extreme"
    # Heavy monsoon rain
    elsif precipitation_mm >= 10.0 || [63, 65, 81].include?(weather_code)
      "high"
    # Moderate showers or dense drizzle
    elsif precipitation_mm >= 2.5 || [53, 55, 61, 80].include?(weather_code)
      "moderate"
    # Dry or light drizzle
    else
      "low"
    end
  end

  def fallback_data
    db_level = fallback_location&.rainfall_level.to_s.downcase.strip.presence || "moderate"
    normalized_level = case db_level
                       when "extreme", "extreme rainfall" then "extreme"
                       when "high", "high rainfall"       then "high"
                       when "low", "low rainfall"         then "low"
                       else "moderate"
                       end

    precip_val = case normalized_level
                 when "extreme"  then 38.5
                 when "high"     then 16.2
                 when "moderate" then 4.5
                 else 0.0
                 end

    {
      temperature: 24.0,
      precipitation: precip_val,
      rainfall: precip_val,
      wind_speed: 12.0,
      weather_code: 0,
      condition_text: "Regional Baseline Pattern (#{normalized_level.capitalize})",
      rainfall_level: normalized_level,
      humidity: 75.0,
      fetched_at: Time.current,
      source: "demo_fallback"
    }
  end
end
