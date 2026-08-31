require "test_helper"

class GeocodingServiceTest < ActiveSupport::TestCase
  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    @location = Location.find_or_create_by!(name: "Testville Hub") do |l|
      l.state = "Assam"
      l.district = "Kamrup"
      l.latitude = 26.50
      l.longitude = 91.50
    end
  end

  teardown do
    Rails.cache = @original_cache
  end

  test "returns instant db match when location exists locally" do
    result = GeocodingService.search("Testville Hub")

    assert_not_nil result
    assert_equal "Testville Hub", result[:name]
    assert_equal 26.50, result[:latitude]
    assert_equal 91.50, result[:longitude]
    assert_equal "db_match", result[:source]
  end

  test "returns normalized coordinates on successful live Nominatim response" do
    mock_payload = {
      name: "Imphal",
      latitude: 24.8170,
      longitude: 93.9368,
      display_name: "Imphal, Manipur, India",
      source: "live"
    }

    service = GeocodingService.new("Imphal")
    with_fake_nominatim(service, mock_payload) do
      result = service.search(force_refresh: true)

      assert_not_nil result
      assert_equal "Imphal", result[:name]
      assert_equal 24.8170, result[:latitude]
      assert_equal 93.9368, result[:longitude]
      assert_equal "live", result[:source]
    end
  end

  test "handles empty, blank or invalid location query gracefully" do
    assert_nil GeocodingService.search(nil)
    assert_nil GeocodingService.search("")
    assert_nil GeocodingService.search("   ")
  end

  test "falls back gracefully on API timeout or network failure" do
    service = GeocodingService.new("Testville City Area")
    with_fake_nominatim(service, -> { raise Net::ReadTimeout, "Execution expired" }) do
      result = service.search(force_refresh: true)

      assert_not_nil result
      assert_equal "Testville Hub", result[:name]
      assert_equal "demo_fallback", result[:source]
    end
  end

  test "caches geocoding results to prevent redundant API queries" do
    call_count = 0
    mock_payload = {
      name: "Kohima",
      latitude: 25.6747,
      longitude: 94.1100,
      display_name: "Kohima, Nagaland, India",
      source: "live"
    }

    service1 = GeocodingService.new("Kohima")
    with_fake_nominatim(service1, -> { call_count += 1; mock_payload }) do
      res1 = service1.search(force_refresh: true)
      assert_equal "live", res1[:source]
      assert_equal 1, call_count
    end

    service2 = GeocodingService.new("Kohima")
    with_fake_nominatim(service2, -> { raise "Should not hit API when cached" }) do
      res2 = service2.search(force_refresh: false)
      assert_equal "live", res2[:source]
      assert_equal 25.6747, res2[:latitude]
      assert_equal 1, call_count, "Expected cache hit without incrementing API calls"
    end
  end

  private

  def with_fake_nominatim(service, payload_or_proc)
    eigenclass = class << service; self; end
    if payload_or_proc.is_a?(Proc)
      eigenclass.define_method(:fetch_from_nominatim, &payload_or_proc)
    else
      eigenclass.define_method(:fetch_from_nominatim) { payload_or_proc }
    end
    yield
  ensure
    eigenclass.remove_method(:fetch_from_nominatim) if eigenclass.method_defined?(:fetch_from_nominatim)
  end
end
