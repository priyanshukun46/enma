require "test_helper"

class WeatherServiceTest < ActiveSupport::TestCase
  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    @location = locations(:one)
    @location.update!(rainfall_level: "high") if @location.present?
  end

  teardown do
    Rails.cache = @original_cache
  end

  test "returns normalized data on successful live API response" do
    mock_payload = {
      temperature: 28.4,
      precipitation: 15.6,
      rainfall: 15.6,
      wind_speed: 14.2,
      weather_code: 65,
      condition_text: "Heavy Monsoon Rain",
      rainfall_level: "high",
      humidity: 82.0,
      fetched_at: Time.current,
      source: "live"
    }

    service = WeatherService.new(latitude: 26.1445, longitude: 91.7362, fallback_location: @location)
    with_fake_api(service, mock_payload) do
      result = service.fetch(force_refresh: true)

      assert_equal "live", result[:source]
      assert_equal 28.4, result[:temperature]
      assert_equal 15.6, result[:precipitation]
      assert_equal 15.6, result[:rainfall]
      assert_equal 14.2, result[:wind_speed]
      assert_equal 65, result[:weather_code]
      assert_equal "Heavy Monsoon Rain", result[:condition_text]
      assert_equal "high", result[:rainfall_level]
      assert_equal 82.0, result[:humidity]
      assert result[:fetched_at].present?
    end
  end

  test "falls back to demo environmental data gracefully on API timeout" do
    service = WeatherService.new(latitude: 26.1445, longitude: 91.7362, fallback_location: @location)
    with_fake_api(service, -> { raise Net::ReadTimeout, "Execution expired" }) do
      result = service.fetch(force_refresh: true)

      assert_equal "demo_fallback", result[:source]
      assert_equal 24.0, result[:temperature]
      assert result[:precipitation] >= 0.0
      assert_equal "high", result[:rainfall_level] # Derived from @location.rainfall_level
      assert result[:condition_text].include?("Regional Baseline")
    end
  end

  test "handles invalid or blank coordinates gracefully" do
    result = WeatherService.fetch(nil, nil, fallback_location: @location)

    assert_equal "demo_fallback", result[:source]
    assert_equal 24.0, result[:temperature]
    assert_equal "high", result[:rainfall_level]
  end

  test "caches weather responses to avoid redundant network calls" do
    call_count = 0
    mock_payload = {
      temperature: 22.0,
      precipitation: 3.0,
      rainfall: 3.0,
      wind_speed: 8.0,
      weather_code: 61,
      condition_text: "Slight Rain",
      rainfall_level: "moderate",
      humidity: 70.0,
      fetched_at: Time.current,
      source: "live"
    }

    mock_fetcher = -> {
      call_count += 1
      mock_payload
    }

    service1 = WeatherService.new(latitude: 27.58, longitude: 91.86, fallback_location: @location)
    with_fake_api(service1, mock_fetcher) do
      res1 = service1.fetch(force_refresh: true)
      assert_equal "live", res1[:source]
      assert_equal 22.0, res1[:temperature]
      assert_equal 1, call_count
    end

    # Second call for the same coordinates should read from MemoryStore without invoking fetch_from_api
    service2 = WeatherService.new(latitude: 27.58, longitude: 91.86, fallback_location: @location)
    with_fake_api(service2, -> { raise "Should not hit API when cached" }) do
      res2 = service2.fetch(force_refresh: false)
      assert_equal "cached_live", res2[:source]
      assert_equal 22.0, res2[:temperature]
      assert_equal 1, call_count, "Expected cache to be used without incrementing network call count"
    end
  end

  test "correctly derives rainfall levels from precipitation and weather codes" do
    service = WeatherService.new(latitude: 26.0, longitude: 92.0)

    assert_equal "extreme", service.send(:derive_rainfall_level, 35.0, 61)
    assert_equal "extreme", service.send(:derive_rainfall_level, 10.0, 95) # Thunderstorm
    assert_equal "extreme", service.send(:derive_rainfall_level, 5.0, 82) # Cloudburst
    assert_equal "high", service.send(:derive_rainfall_level, 15.0, 61)
    assert_equal "high", service.send(:derive_rainfall_level, 2.0, 65) # Heavy Rain code
    assert_equal "moderate", service.send(:derive_rainfall_level, 4.0, 0)
    assert_equal "low", service.send(:derive_rainfall_level, 0.5, 0)
  end

  test "parse_weather_response formats Open-Meteo json correctly" do
    service = WeatherService.new(latitude: 26.0, longitude: 92.0)
    json = {
      "current" => {
        "temperature_2m" => 25.5,
        "precipitation" => 12.0,
        "rain" => 12.0,
        "wind_speed_10m" => 16.5,
        "weather_code" => 63,
        "relative_humidity_2m" => 80.0
      }
    }

    parsed = service.send(:parse_weather_response, json)
    assert_equal "live", parsed[:source]
    assert_equal 25.5, parsed[:temperature]
    assert_equal 12.0, parsed[:precipitation]
    assert_equal 16.5, parsed[:wind_speed]
    assert_equal "Moderate Rain", parsed[:condition_text]
    assert_equal "high", parsed[:rainfall_level]
  end

  private

  def with_fake_api(service, payload_or_proc)
    eigenclass = class << service; self; end
    if payload_or_proc.is_a?(Proc)
      eigenclass.define_method(:fetch_from_api, &payload_or_proc)
    else
      eigenclass.define_method(:fetch_from_api) { payload_or_proc }
    end
    yield
  ensure
    eigenclass.remove_method(:fetch_from_api) if eigenclass.method_defined?(:fetch_from_api)
  end
end
