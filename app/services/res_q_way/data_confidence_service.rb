# frozen_string_literal: true

module ResQWay
  class DataConfidenceService
    EARTH_RADIUS_KM = 6371.0

    # Northeast India Operational Bounding Box
    NE_BOUNDS = {
      min_lat: 21.5,
      max_lat: 29.5,
      min_lon: 89.5,
      max_lon: 97.5
    }.freeze

    # Confidence Thresholds
    LEVEL_VERIFIED = 90.0
    LEVEL_HIGH     = 75.0
    LEVEL_MODERATE = 55.0

    # Signal Maximum Allocations (Sum = 100)
    MAX_GPS          = 20.0
    MAX_EVIDENCE     = 20.0
    MAX_FRESHNESS    = 15.0
    MAX_ENVIRONMENT  = 20.0
    MAX_CONSENSUS    = 15.0
    MAX_REPORTER     = 10.0

    # Related Incident Categories for Spatial Consensus
    RELATED_INCIDENT_TYPES = {
      "landslide"          => %w[landslide road_damage bridge_damage],
      "road_damage"        => %w[road_damage landslide bridge_damage traffic_blockage],
      "bridge_damage"      => %w[bridge_damage road_damage flood],
      "flood"              => %w[flood weather_disruption road_damage],
      "weather_disruption" => %w[weather_disruption flood landslide],
      "traffic_blockage"   => %w[traffic_blockage accident road_damage],
      "accident"           => %w[accident traffic_blockage road_damage],
      "other"              => %w[other road_damage]
    }.freeze

    ALLOWED_IMAGE_TYPES = %w[image/jpeg image/jpg image/png image/webp].freeze
    MAX_IMAGE_SIZE      = 10.megabytes

    attr_reader :incident

    def initialize(incident)
      @incident = incident
    end

    def analyze
      gps_res      = evaluate_gps
      evidence_res = evaluate_evidence
      fresh_res    = evaluate_freshness
      env_res      = evaluate_environmental
      cons_res     = evaluate_spatial_consensus
      rep_res      = evaluate_reporter

      factors = {
        gps: gps_res,
        evidence: evidence_res,
        freshness: fresh_res,
        environmental: env_res,
        spatial_consensus: cons_res,
        reporter: rep_res
      }

      breakdown = {
        gps_authenticity: gps_res,
        photographic_evidence: evidence_res,
        temporal_freshness: fresh_res,
        environmental_weather: env_res,
        spatial_consensus: cons_res,
        reporter_reliability: rep_res
      }

      # 1. Data Trust Score (0-100): Credibility of factual occurrence
      # Excludes freshness decay; scaled across non-freshness signals (max 85 -> 100)
      trust_raw = gps_res[:score] + evidence_res[:score] + env_res[:score] + cons_res[:score] + rep_res[:score]
      data_trust = ((trust_raw / 85.0) * 100.0).clamp(0.0, 100.0).round(1)

      # 2. Operational Relevance Score (0-100): Value for real-time dispatch (heavily decays with age)
      # Freshness ratio (0.0 to 1.0) directly attenuates historical trust
      freshness_ratio = fresh_res[:score] / MAX_FRESHNESS
      operational_relevance = (data_trust * (0.35 + (0.65 * freshness_ratio))).clamp(0.0, 100.0).round(1)

      # 3. Overall Confidence Score (0-100): Decision support composite
      raw_total = gps_res[:score] + evidence_res[:score] + fresh_res[:score] +
                  env_res[:score] + cons_res[:score] + rep_res[:score]
      overall = raw_total.clamp(0.0, 100.0).round(1)

      level = classify_confidence_level(overall)
      explanations = compile_explanations(factors)
      warnings = compile_warnings(factors)
      recs = generate_actionable_recommendations(factors, overall, level)
      summary_text = build_summary(factors, overall, level)

      {
        overall_confidence: overall,
        confidence_level: level,
        data_trust_score: data_trust,
        operational_relevance_score: operational_relevance,
        factors: factors,
        breakdown: breakdown,
        explanation: explanations,
        warnings: warnings,
        actionable_recommendations: recs,
        summary: summary_text,
        calculated_at: Time.current
      }
    end
    alias calculate analyze

    def calculate_and_save!
      analysis = analyze

      # Safe persistence avoiding callback recursion
      if incident.persisted?
        incident.update_columns(
          ai_confidence_score: analysis[:overall_confidence],
          ai_classification_json: analysis.to_json,
          updated_at: Time.current
        )
      else
        incident.ai_confidence_score = analysis[:overall_confidence]
        incident.ai_classification_json = analysis.to_json
      end

      analysis
    end

    # Public helper methods for testing individual signals
    def evaluate_gps
      lat = incident.latitude&.to_f
      lon = incident.longitude&.to_f

      if lat.nil? || lon.nil?
        return {
          score: 0.0,
          max: MAX_GPS,
          status: "missing",
          details: { within_bounds: false, high_precision: false },
          warnings: ["GPS coordinates are missing from the report."],
          explanation: "GPS coordinates are missing from the report."
        }
      end

      unless lat.between?(-90.0, 90.0) && lon.between?(-180.0, 180.0)
        return {
          score: 0.0,
          max: MAX_GPS,
          status: "invalid",
          details: { within_bounds: false, high_precision: false },
          warnings: ["GPS coordinates are outside valid global geographical ranges."],
          explanation: "GPS coordinates are outside valid global geographical ranges."
        }
      end

      # Reject Null Island (0,0)
      if lat.abs < 0.001 && lon.abs < 0.001
        return {
          score: 0.0,
          max: MAX_GPS,
          status: "invalid",
          details: { within_bounds: false, high_precision: false },
          warnings: ["GPS coordinates point to invalid null location (0,0)."],
          explanation: "GPS coordinates point to invalid null location (0,0)."
        }
      end

      # Check Northeast India operational bounding box
      in_ne = lat.between?(NE_BOUNDS[:min_lat], NE_BOUNDS[:max_lat]) &&
              lon.between?(NE_BOUNDS[:min_lon], NE_BOUNDS[:max_lon])

      unless in_ne
        return {
          score: 5.0,
          max: MAX_GPS,
          status: "outside_region",
          details: { within_bounds: false, high_precision: false, lat: lat, lon: lon },
          warnings: ["GPS coordinates (#{lat.round(4)}, #{lon.round(4)}) fall outside the Northeast India operational envelope."],
          explanation: "GPS coordinates fall outside the Northeast India operational region."
        }
      end

      # Evaluate coordinate precision
      lat_s = lat.to_s.split(".").last || ""
      lon_s = lon.to_s.split(".").last || ""
      precision_digits = [lat_s.length, lon_s.length].min
      high_prec = precision_digits >= 3

      score = high_prec ? 20.0 : 12.0
      warnings = high_prec ? [] : ["Low GPS coordinate resolution (< 3 decimal places)."]
      explanation = high_prec ? "High-precision GPS fix verified within Northeast India." : "Coarse GPS fix with low decimal precision."

      {
        score: score,
        max: MAX_GPS,
        status: high_prec ? "verified" : "coarse",
        details: { within_bounds: true, high_precision: high_prec, lat: lat, lon: lon },
        warnings: warnings,
        explanation: explanation
      }
    end

    def evaluate_evidence
      photos = incident.photos
      has_photos = photos.respond_to?(:attached?) && photos.attached?

      unless has_photos
        return {
          score: 0.0,
          max: MAX_EVIDENCE,
          status: "no_evidence",
          photo_count: 0,
          details: { total_count: 0, valid_count: 0 },
          warnings: ["Report lacks photographic evidence attachments."],
          explanation: "No photographic evidence attached to report."
        }
      end

      count = photos.count
      valid_count = 0
      warnings = []

      photos.each do |p|
        next unless p.blob
        is_type = ALLOWED_IMAGE_TYPES.include?(p.blob.content_type.to_s.downcase)
        is_size = p.blob.byte_size.positive? && p.blob.byte_size <= MAX_IMAGE_SIZE

        if is_type && is_size
          valid_count += 1
        else
          warnings << "Attached photo '#{p.blob.filename}' has unrecognized or invalid file format/size."
        end
      end

      score = case valid_count
              when 0 then 0.0
              when 1 then 8.0
              when 2 then 14.0
              else 20.0
              end

      status_label = valid_count >= 3 ? "strong" : (valid_count >= 1 ? "moderate" : "invalid")

      explanation = if valid_count >= 3
                      "Multiple verified photographic evidence files (#{valid_count}) attached."
                    elsif valid_count >= 1
                      "Photographic evidence (#{valid_count} file) attached."
                    else
                      "Attached files failed image validation specifications."
                    end

      {
        score: score,
        max: MAX_EVIDENCE,
        status: status_label,
        photo_count: valid_count,
        details: { total_count: count, valid_count: valid_count },
        warnings: warnings,
        explanation: explanation
      }
    end

    def evaluate_freshness
      time = incident.reported_at || incident.created_at || Time.current
      age_seconds = [Time.current - time, 0.0].max
      age_hours = age_seconds / 3600.0

      score = if age_hours < 0.5
                15.0
              elsif age_hours > 40.0
                (15.0 * Math.exp(-age_hours / 15.0)).clamp(0.0, 1.0).round(1)
              else
                (15.0 * Math.exp(-age_hours / 15.0)).clamp(0.0, 15.0).round(1)
              end

      status_label = if age_hours < 1.0
                       "fresh"
                     elsif age_hours < 6.0
                       "recent"
                     elsif age_hours < 24.0
                       "aging"
                     else
                       "historical"
                     end

      explanation = if age_hours < 1.0
                      "Report is fresh (< 1h old) with high tactical dispatch value."
                    elsif age_hours < 6.0
                      "Report was filed recently (#{age_hours.round(1)}h ago)."
                    elsif age_hours < 24.0
                      "Report is #{age_hours.round(1)}h old; conditions may have evolved."
                    else
                      "Report is #{age_hours.round(1)}h old; historical value retained."
                    end

      warnings = age_hours > 24.0 ? ["Report is over 24 hours old; ground conditions may have changed significantly."] : []

      {
        score: score,
        max: MAX_FRESHNESS,
        status: status_label,
        details: { age_hours: age_hours.round(1) },
        warnings: warnings,
        explanation: explanation
      }
    end

    def evaluate_environmental
      lat = incident.latitude&.to_f
      lon = incident.longitude&.to_f

      if lat.nil? || lon.nil?
        return {
          score: 10.0,
          max: MAX_ENVIRONMENT,
          status: "unknown",
          details: { data_available: false, corroborated: false },
          warnings: ["Weather service unavailable: missing coordinates."],
          explanation: "Environmental corroboration unavailable because coordinates are missing."
        }
      end

      weather = begin
        if defined?(WeatherService)
          WeatherService.fetch(lat, lon)
        else
          nil
        end
      rescue StandardError => e
        Rails.logger.warn("[DataConfidence] Weather fetch error: #{e.message}")
        nil
      end

      if weather.nil?
        return {
          score: 10.0,
          max: MAX_ENVIRONMENT,
          status: "unknown",
          details: { data_available: false, corroborated: false },
          warnings: ["Weather service unavailable; neutral fallback score applied."],
          explanation: "Environmental corroboration unavailable because weather telemetry could not be retrieved."
        }
      end

      precip = (weather[:precipitation] || weather[:precipitation_mm]).to_f
      rain_level = (weather[:rainfall] || weather[:rainfall_level]).to_s.downcase
      condition = (weather[:condition] || weather[:condition_text]).to_s.downcase
      alerts = Array(weather[:alerts])
      type = incident.incident_type.to_s.downcase

      warnings = []

      # Detect weather mismatch
      is_dry = (precip <= 0.5) && (%w[none low].include?(rain_level) || rain_level.blank?) &&
               (condition.include?("clear") || condition.include?("sun") || rain_level == "none")

      if %w[flood landslide].include?(type) && is_dry
        score = 0.0
        status = "mismatch"
        warnings << "Weather mismatch: clear skies or zero precipitation recorded during active #{type} hazard."
        explanation = "Atmospheric conditions do not corroborate reported #{type}."
        corroborated = false
      elsif type == "landslide" && (precip >= 15.0 || %w[heavy extreme].include?(rain_level) || condition.include?("rain") || alerts.any?)
        score = 20.0
        status = "corroborated"
        explanation = "Heavy rainfall conditions (#{precip} mm, #{rain_level}) corroborate landslide hazard triggers."
        corroborated = true
      elsif type == "flood" && (precip >= 20.0 || %w[heavy extreme].include?(rain_level) || condition.include?("rain") || condition.include?("flood"))
        score = 20.0
        status = "corroborated"
        explanation = "Torrential precipitation (#{precip} mm) strongly corroborates flood report."
        corroborated = true
      elsif type == "weather_disruption" && (precip >= 10.0 || condition.include?("storm") || condition.include?("rain"))
        score = 20.0
        status = "corroborated"
        explanation = "Active atmospheric storm telemetry corroborates weather disruption."
        corroborated = true
      elsif precip >= 5.0 || rain_level == "moderate"
        score = 15.0
        status = "partially_corroborated"
        explanation = "Moderate precipitation (#{precip} mm) partially corroborates regional condition."
        corroborated = true
      else
        score = 10.0
        status = "neutral"
        explanation = "Environmental conditions are neutral for this incident report."
        corroborated = false
      end

      {
        score: score,
        max: MAX_ENVIRONMENT,
        status: status,
        details: { data_available: true, corroborated: corroborated, precipitation_mm: precip, rainfall: rain_level },
        warnings: warnings,
        explanation: explanation
      }
    end

    def evaluate_spatial_consensus
      lat = incident.latitude&.to_f
      lon = incident.longitude&.to_f

      if lat.nil? || lon.nil?
        return {
          score: 0.0,
          max: MAX_CONSENSUS,
          status: "isolated_report",
          details: { nearby_matching_count: 0, nearby_other_count: 0 },
          warnings: [],
          explanation: "Spatial consensus unverified without valid coordinates."
        }
      end

      delta = 0.18 # ~20km bounding box
      time_cutoff = 24.hours.ago

      scope = Incident.where("reported_at >= ? OR created_at >= ?", time_cutoff, time_cutoff)
                      .where(latitude: (lat - delta)..(lat + delta))
                      .where(longitude: (lon - delta)..(lon + delta))

      scope = scope.where.not(id: incident.id) if incident.persisted?

      candidates = scope.limit(50).to_a
      within_15km = candidates.select do |c|
        haversine_distance(lat, lon, c.latitude, c.longitude) <= 15.0
      end

      matching = within_15km.select { |c| c.incident_type == incident.incident_type }
      other = within_15km.reject { |c| c.incident_type == incident.incident_type }

      matching_count = matching.size
      other_count = other.size

      score, status_label, explanation = if matching_count >= 3
                                           [15.0, "high_consensus", "#{matching_count} matching reports corroborate cluster hazard within 15 km."]
                                         elsif matching_count >= 1
                                           [10.0, "moderate_consensus", "#{matching_count} matching report(s) nearby corroborating disruption."]
                                         elsif other_count >= 1
                                           [7.5, "partial_consensus", "#{other_count} related disaster incidents active in this immediate sector."]
                                         else
                                           [0.0, "isolated_report", "Isolated report; no corroborating field reports within 15 km."]
                                         end

      {
        score: score,
        max: MAX_CONSENSUS,
        status: status_label,
        details: { nearby_matching_count: matching_count, nearby_other_count: other_count },
        warnings: [],
        explanation: explanation
      }
    end

    def evaluate_reporter_reliability
      user = incident.user

      if user.nil?
        return {
          score: 6.0,
          max: MAX_REPORTER,
          status: "neutral_baseline",
          details: { history_status: "neutral_baseline", total_reports: 0 },
          warnings: ["Report submitted without registered field officer profile; neutral baseline assigned."],
          explanation: "Anonymous or unregistered reporter; neutral baseline applied."
        }
      end

      prev_scope = user.incidents
      prev_scope = prev_scope.where.not(id: incident.id) if incident.persisted?

      total_prev = prev_scope.count
      if total_prev.zero?
        return {
          score: 6.0,
          max: MAX_REPORTER,
          status: "neutral_baseline",
          details: { history_status: "neutral_baseline", total_reports: 0 },
          warnings: [],
          explanation: "New authorized field officer (#{user.name}) with zero prior reports; neutral baseline assigned."
        }
      end

      verified_count = prev_scope.where(status: %w[verified resolved]).count
      rejected_count = prev_scope.where(status: "rejected").count

      valid_ratio = verified_count.to_f / total_prev.to_f
      rejection_ratio = rejected_count.to_f / total_prev.to_f

      warnings = []

      score = if user.respond_to?(:admin?) && user.admin?
                10.0
              elsif rejection_ratio >= 0.5 && rejected_count >= 3
                warnings << "Reporter history shows an elevated rejection rate."
                (2.0 - (rejection_ratio * 1.5)).clamp(0.0, 2.0).round(1)
              elsif total_prev >= 3 && valid_ratio >= 0.75
                10.0
              elsif total_prev >= 1 && verified_count >= 1
                (6.0 + (valid_ratio * 4.0)).clamp(6.0, 10.0).round(1)
              else
                6.0
              end

      status_label = score >= 9.0 ? "reliable" : (score >= 6.0 ? "neutral" : "unreliable")
      explanation = if score >= 9.0
                      "Reporter (#{user.name}) has a verified track record of #{verified_count} accepted reports."
                    elsif score <= 3.0
                      "Reporter has multiple rejected submissions."
                    else
                      "Reporter has active standard credentials."
                    end

      {
        score: score,
        max: MAX_REPORTER,
        status: status_label,
        details: { history_status: "active", verification_ratio: valid_ratio, total_reports: total_prev },
        warnings: warnings,
        explanation: explanation
      }
    end
    alias evaluate_reporter evaluate_reporter_reliability

    # =========================================================================
    # HELPERS
    # =========================================================================
    private

    def classify_confidence_level(score)
      if score >= LEVEL_VERIFIED
        "VERIFIED"
      elsif score >= LEVEL_HIGH
        "HIGH"
      elsif score >= LEVEL_MODERATE
        "MODERATE"
      else
        "LOW"
      end
    end

    def compile_explanations(factors)
      list = []
      factors.each_value do |f|
        list << f[:explanation] if f[:explanation].present?
      end
      list.compact.uniq
    end

    def compile_warnings(factors)
      warnings = []
      factors.each_value do |f|
        warnings.concat(Array(f[:warnings])) if f[:warnings].present?
      end
      warnings.compact.uniq
    end

    def generate_actionable_recommendations(factors, score, level)
      recs = []

      if level == "VERIFIED"
        recs << "Proceed with high-confidence automated logistics rerouting and corridor isolation."
        recs << "Escalate critical supply convoy reallocations immediately to avoid blockage."
      elsif level == "HIGH"
        recs << "Implement precautionary route rerouting for critical emergency supplies."
        recs << "Request routine patrol visual confirmation."
      elsif level == "MODERATE"
        recs << "Dispatch local reconnaissance scout or UAV patrol before committing full convoy reroute."
        recs << "Monitor nearby vehicle GPS telemetries for slowdowns."
      else
        recs << "Information unverified. Do not close regional network corridors without physical verification."
        recs << "Dispatch field officer to confirm coordinates and hazard severity."
      end

      if factors[:evidence][:photo_count].to_i.zero?
        recs << "Request high-resolution visual evidence upload from field units."
      end

      recs
    end

    def build_summary(factors, score, level)
      "Multi-source confidence calculated at #{score}/100 (#{level}). Assessed across GPS authenticity, photographic evidence, temporal freshness, environmental weather, spatial consensus, and reporter reliability."
    end

    def haversine_distance(lat1, lon1, lat2, lon2)
      return 9999.0 if lat1.nil? || lon1.nil? || lat2.nil? || lon2.nil?

      dlat = (lat2 - lat1) * Math::PI / 180.0
      dlon = (lon2 - lon1) * Math::PI / 180.0

      a = (Math.sin(dlat / 2.0)**2) +
          (Math.cos(lat1 * Math::PI / 180.0) * Math.cos(lat2 * Math::PI / 180.0) * (Math.sin(dlon / 2.0)**2))
      c = 2.0 * Math.atan2(Math.sqrt(a), Math.sqrt(1.0 - a))
      (EARTH_RADIUS_KM * c).round(2)
    end
  end
end
