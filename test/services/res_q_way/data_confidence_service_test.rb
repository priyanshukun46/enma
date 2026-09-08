# frozen_string_literal: true

require "test_helper"

module ResQWay
  class DataConfidenceServiceTest < ActiveSupport::TestCase
    def setup
      Incident.delete_all
      User.delete_all

      @officer = User.create!(
        name: "Capt. Wangchuk",
        email_address: "wangchuk_#{SecureRandom.hex(4)}@enma.ai",
        password: "password123",
        role: :operator
      )

      @incident = Incident.new(
        incident_type: "landslide",
        severity: "critical",
        status: "reported",
        description: "Massive debris blocking NH-13 along Sela Pass corridor.",
        latitude: 27.5855,
        longitude: 91.8679,
        location_name: "Sela Pass Detour",
        district: "Tawang",
        state: "Arunachal Pradesh",
        reported_at: 10.minutes.ago,
        user: @officer
      )
    end

    def with_mock_weather(mock_data_or_proc)
      singleton = WeatherService.singleton_class
      orig_method = WeatherService.method(:fetch)
      singleton.send(:define_method, :fetch) do |*args|
        if mock_data_or_proc.is_a?(Proc)
          mock_data_or_proc.call(*args)
        else
          mock_data_or_proc
        end
      end
      yield
    ensure
      singleton.send(:define_method, :fetch, orig_method)
    end

    # =========================================================================
    # SCENARIO 1: Optimal 6-Factor Perfect Confidence (Score: 100)
    # =========================================================================
    test "scenario 1: full score when all 6 factors optimal" do
      # 1. GPS: 27.5855, 91.8679 -> Valid NE India, 4 decimals (20 pts)
      # 2. Photos: 3 valid photos (20 pts)
      3.times do |i|
        @incident.photos.attach(
          io: StringIO.new("fake_valid_jpg_content_#{i}"),
          filename: "evidence_#{i}.jpg",
          content_type: "image/jpeg"
        )
      end
      @incident.save!

      # 3. Reporter: 10 verified, 0 rejected (10 pts)
      10.times do |i|
        Incident.create!(
          incident_type: "landslide",
          severity: "high",
          status: "verified",
          description: "Corroborated historical slide event #{i}",
          latitude: 27.58,
          longitude: 91.86,
          reported_at: 1.day.ago,
          user: @officer
        )
      end

      # 4. Spatial consensus: 3 matching nearby reports within 10 km (15 pts)
      3.times do |i|
        Incident.create!(
          incident_type: "landslide",
          severity: "high",
          status: "reported",
          description: "Nearby rockfall report #{i}",
          latitude: 27.5860 + (i * 0.002),
          longitude: 91.8680 + (i * 0.002),
          reported_at: 15.minutes.ago
        )
      end

      # 5. Weather: Landslide with heavy rainfall (20 pts)
      weather_data = {
        temperature: 16.0,
        rainfall: "heavy",
        precipitation_mm: 55.0,
        condition: "Heavy Monsoon Rain",
        wind_speed: 35.0,
        alerts: ["Heavy rainfall warning"]
      }

      with_mock_weather(weather_data) do
        service = ResQWay::DataConfidenceService.new(@incident)
        res = service.calculate

        assert_equal 100.0, res[:overall_confidence]
        assert_equal 100.0, res[:data_trust_score]
        assert_equal 100.0, res[:operational_relevance_score]
        assert_equal "VERIFIED", res[:confidence_level]
        assert res[:actionable_recommendations].any?
      end
    end

    # =========================================================================
    # SCENARIO 2: Low Score Unverified Single Report (~36 pts)
    # =========================================================================
    test "scenario 2: low score when unverified single report with weather mismatch and no photos" do
      # Truncated GPS (12 pts), no photos (0 pts), fresh (15 pts),
      # flood with clear weather (0 pts), 0 nearby (0 pts), neutral reporter (6 pts) -> ~33
      @incident.latitude = 26.1
      @incident.longitude = 91.7
      @incident.incident_type = "flood"
      @incident.user = nil # anonymous / new reporter -> 6 pts
      @incident.save!

      dry_weather = {
        temperature: 32.0,
        rainfall: "none",
        precipitation_mm: 0.0,
        condition: "Clear",
        wind_speed: 5.0,
        alerts: []
      }

      with_mock_weather(dry_weather) do
        service = ResQWay::DataConfidenceService.new(@incident)
        res = service.calculate

        assert res[:overall_confidence] < 55.0, "Expected low score, got #{res[:overall_confidence]}"
        assert_equal "LOW", res[:confidence_level]
        assert res[:warnings].any? { |w| w.include?("Weather mismatch") }
      end
    end

    # =========================================================================
    # SCENARIO 3: Photo Scoring Gradient (0=0, 1=8, 2=14, 3+=20)
    # =========================================================================
    test "scenario 3: photo scoring gradient across count" do
      service = ResQWay::DataConfidenceService.new(@incident)

      # 0 photos
      assert_equal 0.0, service.evaluate_evidence[:score]

      # 1 photo
      @incident.photos.attach(io: StringIO.new("img1"), filename: "1.jpg", content_type: "image/jpeg")
      assert_equal 8.0, service.evaluate_evidence[:score]

      # 2 photos
      @incident.photos.attach(io: StringIO.new("img2"), filename: "2.png", content_type: "image/png")
      assert_equal 14.0, service.evaluate_evidence[:score]

      # 3 photos
      @incident.photos.attach(io: StringIO.new("img3"), filename: "3.webp", content_type: "image/webp")
      assert_equal 20.0, service.evaluate_evidence[:score]

      # 4 photos (capped at 20)
      @incident.photos.attach(io: StringIO.new("img4"), filename: "4.jpeg", content_type: "image/jpeg")
      assert_equal 20.0, service.evaluate_evidence[:score]
    end

    # =========================================================================
    # SCENARIO 4: Photo Format Validation
    # =========================================================================
    test "scenario 4: photo format validation accepts valid images and flags unprocessable types" do
      service = ResQWay::DataConfidenceService.new(@incident)

      # Attach unsupported format
      @incident.photos.attach(
        io: StringIO.new("fake_exe_file"),
        filename: "malware.exe",
        content_type: "application/octet-stream"
      )

      res = service.evaluate_evidence
      assert res[:score] < 8.0
      assert res[:warnings].any? { |w| w.include?("unrecognized or invalid") }
    end

    # =========================================================================
    # SCENARIO 5: Valid Northeast India GPS Bounds
    # =========================================================================
    test "scenario 5: valid coordinates within Northeast India bounds receive full GPS score" do
      @incident.latitude = 26.1445
      @incident.longitude = 91.7362
      service = ResQWay::DataConfidenceService.new(@incident)

      res = service.evaluate_gps
      assert_equal 20.0, res[:score]
      assert_equal true, res[:details][:within_bounds]
      assert_equal true, res[:details][:high_precision]
    end

    # =========================================================================
    # SCENARIO 6: GPS Coordinates Outside Northeast India Penalized
    # =========================================================================
    test "scenario 6: coordinates outside Northeast India bounds are penalized" do
      @incident.latitude = 28.6139
      @incident.longitude = 77.2090 # New Delhi (Outside NE India lon: 89.5 - 97.5)
      service = ResQWay::DataConfidenceService.new(@incident)

      res = service.evaluate_gps
      assert_equal 5.0, res[:score]
      assert_equal false, res[:details][:within_bounds]
      assert res[:warnings].any? { |w| w.include?("outside the Northeast India") }
    end

    # =========================================================================
    # SCENARIO 7: Low-Precision GPS Penalized
    # =========================================================================
    test "scenario 7: truncated or low-precision GPS coordinates are penalized" do
      @incident.latitude = 26.1 # only 1 decimal place
      @incident.longitude = 91.7 # only 1 decimal place
      service = ResQWay::DataConfidenceService.new(@incident)

      res = service.evaluate_gps
      assert_equal 12.0, res[:score] # within bounds (15) but lacks precision (-3) = 12
      assert_equal false, res[:details][:high_precision]
      assert res[:warnings].any? { |w| w.include?("Low GPS coordinate resolution") }
    end

    # =========================================================================
    # SCENARIO 8: Temporal Freshness Decay Over 48 Hours
    # =========================================================================
    test "scenario 8: temporal freshness exponential decay curve reduces score over 48 hours" do
      # Under 30 minutes: 15.0
      @incident.reported_at = 20.minutes.ago
      s1 = ResQWay::DataConfidenceService.new(@incident).evaluate_freshness
      assert_equal 15.0, s1[:score]

      # 2 hours ago: ~12.5 - 13.5
      @incident.reported_at = 2.hours.ago
      s2 = ResQWay::DataConfidenceService.new(@incident).evaluate_freshness
      assert s2[:score].between?(11.0, 14.0), "Expected ~12.5-13.5, got #{s2[:score]}"

      # 6 hours ago: ~9.5 - 10.5
      @incident.reported_at = 6.hours.ago
      s3 = ResQWay::DataConfidenceService.new(@incident).evaluate_freshness
      assert s3[:score].between?(8.0, 11.0), "Expected ~9.5-10.5, got #{s3[:score]}"

      # 24 hours ago: ~3.0
      @incident.reported_at = 24.hours.ago
      s4 = ResQWay::DataConfidenceService.new(@incident).evaluate_freshness
      assert s4[:score].between?(2.0, 5.0), "Expected ~3.0, got #{s4[:score]}"

      # 48 hours ago: ~0.7
      @incident.reported_at = 48.hours.ago
      s5 = ResQWay::DataConfidenceService.new(@incident).evaluate_freshness
      assert s5[:score] <= 1.0, "Expected <= 1.0, got #{s5[:score]}"
    end

    # =========================================================================
    # SCENARIO 9: Operational Relevance vs Data Trust Separation
    # =========================================================================
    test "scenario 9: operational relevance separates intrinsic data trust from temporal decay" do
      # Old incident (36 hours ago) with valid evidence and GPS
      @incident.reported_at = 36.hours.ago
      3.times do |i|
        @incident.photos.attach(
          io: StringIO.new("img_#{i}"),
          filename: "img_#{i}.jpg",
          content_type: "image/jpeg"
        )
      end
      @incident.save!

      weather = {
        temperature: 15.0,
        rainfall: "heavy",
        precipitation_mm: 45.0,
        condition: "Rain",
        wind_speed: 20.0,
        alerts: []
      }

      with_mock_weather(weather) do
        res = ResQWay::DataConfidenceService.new(@incident).calculate

        # Intrinsic trust should remain solid (~70-85 pts)
        assert res[:data_trust_score] >= 70.0, "Expected data trust >= 70, got #{res[:data_trust_score]}"
        # Operational relevance should be significantly lower due to 36h age
        assert res[:operational_relevance_score] < res[:data_trust_score], "Relevance should decay below trust"
        assert res[:operational_relevance_score] <= 50.0, "Expected operational relevance <= 50, got #{res[:operational_relevance_score]}"
      end
    end

    # =========================================================================
    # SCENARIO 10: Weather Corroboration for Rain + Landslide
    # =========================================================================
    test "scenario 10: weather corroboration gives full score for landslide under heavy rainfall" do
      @incident.incident_type = "landslide"

      storm_weather = {
        temperature: 18.0,
        rainfall: "heavy",
        precipitation_mm: 65.0,
        condition: "Torrential Downpour",
        wind_speed: 40.0,
        alerts: ["Red alert for landslides"]
      }

      with_mock_weather(storm_weather) do
        res = ResQWay::DataConfidenceService.new(@incident).evaluate_environmental
        assert_equal 20.0, res[:score]
        assert_equal true, res[:details][:corroborated]
      end
    end

    # =========================================================================
    # SCENARIO 11: Weather Mismatch Penalty Flag
    # =========================================================================
    test "scenario 11: weather mismatch gives zero corroboration and penalty flag" do
      @incident.incident_type = "flood"

      bone_dry_weather = {
        temperature: 35.0,
        rainfall: "none",
        precipitation_mm: 0.0,
        condition: "Clear and Sunny",
        wind_speed: 3.0,
        alerts: []
      }

      with_mock_weather(bone_dry_weather) do
        res = ResQWay::DataConfidenceService.new(@incident).evaluate_environmental
        assert_equal 0.0, res[:score]
        assert_equal false, res[:details][:corroborated]
        assert res[:warnings].any? { |w| w.include?("Weather mismatch") }
      end
    end

    # =========================================================================
    # SCENARIO 12: Graceful Degradation on Weather Service Failure
    # =========================================================================
    test "scenario 12: weather unavailable provides graceful neutral degradation" do
      with_mock_weather(->(*_args) { raise StandardError, "Network connection timed out" }) do
        res = ResQWay::DataConfidenceService.new(@incident).evaluate_environmental

        assert_equal 10.0, res[:score] # Neutral 10/20 fallback
        assert_equal false, res[:details][:data_available]
        assert res[:warnings].any? { |w| w.include?("Weather service unavailable") }
      end
    end

    # =========================================================================
    # SCENARIO 13: Spatial Consensus Full Points (3+ Matching Within 15km)
    # =========================================================================
    test "scenario 13: spatial consensus grants full 15 points with 3+ matching nearby reports" do
      @incident.save!

      # Create 3 matching incidents within 5 km
      3.times do |i|
        Incident.create!(
          incident_type: "landslide",
          severity: "high",
          status: "reported",
          description: "Cluster rockfall observation #{i}",
          latitude: @incident.latitude + (0.01 * (i + 1)),
          longitude: @incident.longitude + (0.01 * (i + 1)),
          reported_at: 1.hour.ago
        )
      end

      res = ResQWay::DataConfidenceService.new(@incident).evaluate_spatial_consensus
      assert_equal 15.0, res[:score]
      assert_equal 3, res[:details][:nearby_matching_count]
    end

    # =========================================================================
    # SCENARIO 14: Single Isolated Report Gets 0 Consensus Without Failure
    # =========================================================================
    test "scenario 14: spatial consensus gives 0 points for isolated incident without failure" do
      @incident.save!
      # Zero other incidents in database

      res = ResQWay::DataConfidenceService.new(@incident).evaluate_spatial_consensus
      assert_equal 0.0, res[:score]
      assert_equal 0, res[:details][:nearby_matching_count]
      assert_equal 0, res[:details][:nearby_other_count]
    end

    # =========================================================================
    # SCENARIO 15: Spatial Consensus Partial Credit for Mixed Hazard Types
    # =========================================================================
    test "scenario 15: spatial consensus awards partial credit for different hazard types in cluster" do
      @incident.save!

      # Create 3 incidents within 5 km of DIFFERENT types (e.g. road_damage, flood)
      3.times do |i|
        Incident.create!(
          incident_type: "road_damage",
          severity: "high",
          status: "reported",
          description: "Road washaway observation #{i}",
          latitude: @incident.latitude + (0.01 * (i + 1)),
          longitude: @incident.longitude + (0.01 * (i + 1)),
          reported_at: 1.hour.ago
        )
      end

      res = ResQWay::DataConfidenceService.new(@incident).evaluate_spatial_consensus
      assert_equal 7.5, res[:score]
      assert_equal 0, res[:details][:nearby_matching_count]
      assert_equal 3, res[:details][:nearby_other_count]
    end

    # =========================================================================
    # SCENARIO 16: Reporter Reliability - High Verification Rate (10/10)
    # =========================================================================
    test "scenario 16: reporter reliability awards 10/10 for officer with high verification history" do
      # Officer with 6 verified, 0 rejected
      6.times do |i|
        Incident.create!(
          incident_type: "landslide",
          severity: "high",
          status: "verified",
          description: "Historical confirmed slide #{i}",
          latitude: 27.58,
          longitude: 91.86,
          reported_at: 2.days.ago,
          user: @officer
        )
      end

      res = ResQWay::DataConfidenceService.new(@incident).evaluate_reporter_reliability
      assert_equal 10.0, res[:score]
      assert_equal 1.0, res[:details][:verification_ratio]
    end

    # =========================================================================
    # SCENARIO 17: Reporter Reliability - High Rejection Rate (0-2/10)
    # =========================================================================
    test "scenario 17: reporter reliability scores low for user with high rejection history" do
      # Officer with 0 verified, 6 rejected
      6.times do |i|
        Incident.create!(
          incident_type: "landslide",
          severity: "high",
          status: "rejected",
          description: "Historical false alarm #{i}",
          latitude: 27.58,
          longitude: 91.86,
          reported_at: 2.days.ago,
          user: @officer
        )
      end

      res = ResQWay::DataConfidenceService.new(@incident).evaluate_reporter_reliability
      assert res[:score] <= 2.0, "Expected <= 2.0, got #{res[:score]}"
      assert res[:warnings].any? { |w| w.include?("elevated rejection rate") }
    end

    # =========================================================================
    # SCENARIO 18: Reporter Reliability - Neutral Baseline for New User (6/10)
    # =========================================================================
    test "scenario 18: reporter reliability assigns neutral baseline 6/10 to new user with no history" do
      new_user = User.create!(
        name: "New Cadet",
        email_address: "cadet_#{SecureRandom.hex(4)}@enma.ai",
        password: "password123"
      )
      @incident.user = new_user

      res = ResQWay::DataConfidenceService.new(@incident).evaluate_reporter_reliability
      assert_equal 6.0, res[:score]
      assert_equal "neutral_baseline", res[:details][:history_status]
    end

    # =========================================================================
    # SCENARIO 19: Safe Persistence Without Infinite Loop
    # =========================================================================
    test "scenario 19: calculate_and_save! safely persists without triggering infinite callback loop" do
      @incident.save!

      service = ResQWay::DataConfidenceService.new(@incident)
      result = service.calculate_and_save!

      assert result.is_a?(Hash)
      assert result[:overall_confidence].present?

      # Reload from database to verify safe column update
      @incident.reload
      assert_not_nil @incident.ai_confidence_score
      assert_equal result[:overall_confidence], @incident.ai_confidence_score
      assert_not_nil @incident.ai_classification_json

      # Test model helper methods
      assert_equal @incident.ai_confidence_score, @incident.confidence_score
      assert_includes %w[VERIFIED HIGH MODERATE LOW], @incident.confidence_level
      assert @incident.confidence_badge_class.present?
      assert @incident.as_map_json.key?(:confidence_score)
    end
  end
end
