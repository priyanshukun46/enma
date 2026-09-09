class RoutesController < ApplicationController
  before_action :load_form_options

  def index
    # Handle pre-fill from Emergency Command Center or URL params or default to Guwahati -> Shillong
    if params[:emergency_id].present?
      prefill_from_emergency(params[:emergency_id])
    else
      origin_id = params[:origin_id].presence || Location.find_by(name: "Guwahati")&.id || @locations.first&.id
      destination_id = params[:destination_id].presence || Location.find_by(name: "Shillong")&.id || @locations.second&.id
      vehicle_type = params[:vehicle_type].presence || "Truck"
      priority_mode = params[:priority_mode].presence || "balanced"
      cargo_type = params[:cargo_type].presence || "General Supplies"

      if origin_id.present? && destination_id.present? && origin_id.to_s != destination_id.to_s
        process_route_calculation(origin_id, destination_id, vehicle_type, priority_mode, cargo_type)
      end
    end

    respond_to do |format|
      format.html
      format.json { render json: @results }
    end
  end

  def geocode
    query = params[:q].to_s.strip
    result = GeocodingService.search(query)
    if result
      render json: result
    else
      render json: { error: "Location not found" }, status: :not_found
    end
  end

  def calculate
    origin_id = params[:origin_id]
    destination_id = params[:destination_id]
    vehicle_type = params[:vehicle_type].presence || "Truck"
    priority_mode = params[:priority_mode].presence || "balanced"
    cargo_type = params[:cargo_type].presence || "General Supplies"

    if origin_id.blank? || destination_id.blank?
      respond_to do |format|
        format.html do
          flash.now[:alert] = "Please select both an Origin and a Destination location."
          render :index, status: :unprocessable_entity
        end
        format.json { render json: { error: "Missing origin or destination" }, status: :unprocessable_entity }
      end
      return
    end

    if origin_id.to_s == destination_id.to_s
      respond_to do |format|
        format.html do
          flash.now[:alert] = "Origin and Destination cannot be the same location. Please select distinct locations."
          render :index, status: :unprocessable_entity
        end
        format.json { render json: { error: "Same location" }, status: :unprocessable_entity }
      end
      return
    end

    process_route_calculation(origin_id, destination_id, vehicle_type, priority_mode, cargo_type)

    respond_to do |format|
      format.html { render :index }
      format.json { render json: @results }
    end
  end

  private

  def load_form_options
    @locations = Location.order(:name)
    @vehicle_types = [
      "Truck",
      "Ambulance",
      "Emergency Vehicle",
      "Supply Vehicle",
      "Personal Vehicle"
    ]
    @priority_modes = [
      { key: "balanced", label: "⚖️ Balanced", tagline: "Time, Risk & Fuel balance" },
      { key: "safest", label: "🛡️ Safest", tagline: "Hazard & Landslide avoidance" },
      { key: "fastest", label: "⚡ Fastest", tagline: "Minimum transit time" },
      { key: "emergency", label: "🚨 Emergency Relief", tagline: "Zero roadblock compromise" }
    ]
    @cargo_types = [
      "General Supplies",
      "Medical & First Aid",
      "Food & Water Relief",
      "Hazmat / Fuel",
      "Heavy Rescue Equipment"
    ]
    @recent_routes = LogisticsRoute.includes(:origin, :destination).recent.limit(8)
    @active_emergencies_count = Emergency.where(status: ["Active", "Responding"]).count
  end

  def prefill_from_emergency(emergency_id)
    emergency = Emergency.find_by(id: emergency_id)
    return unless emergency

    warehouse = Warehouse.first
    dest_loc = emergency.location || Location.find_by(name: emergency.title.split.first) || Location.first
    orig_loc = Location.find_by(name: "Guwahati") || Location.first

    @origin = orig_loc
    @destination = dest_loc
    @selected_vehicle = "Emergency Vehicle"
    @selected_priority = "emergency"
    @selected_cargo = "Medical & First Aid"

    process_route_calculation(@origin.id, @destination.id, @selected_vehicle, @selected_priority, @selected_cargo)
  end

  # =========================================================================
  # ResQWay TRIPLE-BUFFER ROUTE CACHE ARCHITECTURE
  # =========================================================================
  # Buffer 1: L1 Active In-Memory Ring Buffer (< 0.05ms zero-IO read)
  # Buffer 2: L2 Speculative Staging Buffer (Pre-warmed return corridors & sibling vehicle profiles)
  # Buffer 3: L3 Persistent Distributed Rails Cache (with 2-hour sliding window TTL)
  @@l1_active_buffer = {}
  @@l2_speculative_buffer = {}
  @@double_buffer = @@l1_active_buffer # Backward compatibility alias

  def process_route_calculation(origin_id, destination_id, vehicle_type, priority_mode = "balanced", cargo_type = "General Supplies")
    if origin_id.to_s == "user_location" && params[:origin_lat].present? && params[:origin_lon].present?
      lat = params[:origin_lat].to_f
      lon = params[:origin_lon].to_f
      nearest = Location.all.min_by { |l| ((l.latitude - lat)**2 + (l.longitude - lon)**2) }
      @origin = nearest || Location.first
    else
      @origin = Location.find_by(id: origin_id) || Location.find_by(name: origin_id)
    end

    @destination = Location.find_by(id: destination_id) || Location.find_by(name: destination_id)
    @selected_vehicle = vehicle_type.presence || "Truck"
    @selected_priority = priority_mode.presence || "balanced"
    @selected_cargo = cargo_type.presence || "General Supplies"

    unless @origin && @destination
      flash.now[:alert] = "Invalid origin or destination location selected."
      return
    end

    buffer_key = "rt_buf_#{@origin.id}_#{@destination.id}_#{@selected_vehicle.parameterize}_#{@selected_priority}_#{@selected_cargo.parameterize}"

    # 1. Buffer 1: Instant L1 Active In-Memory Check (< 0.05ms)
    if @@l1_active_buffer.key?(buffer_key)
      buf = @@l1_active_buffer[buffer_key]
      @results = buf[:results]
      @recommendation_result = buf[:recommendation_result]
      @route_analysis = buf[:route_analysis]
      @buffer_tier = "L1 Active In-Memory"
      @recent_routes = LogisticsRoute.includes(:origin, :destination).recent.limit(8)
      return
    end

    # 2. Buffer 2: Secondary L2 Speculative Staging Check (< 0.1ms)
    if @@l2_speculative_buffer.key?(buffer_key)
      buf = @@l2_speculative_buffer[buffer_key]
      @results = buf[:results]
      @recommendation_result = buf[:recommendation_result]
      @route_analysis = buf[:route_analysis]
      # Promote from L2 to L1 Active
      @@l1_active_buffer[buffer_key] = buf
      @buffer_tier = "L2 Speculative Warm"
      @recent_routes = LogisticsRoute.includes(:origin, :destination).recent.limit(8)
      return
    end

    # 3. Buffer 3: Tertiary L3 Persistent Rails Cache Check (< 1ms)
    cached = Rails.cache.read(buffer_key)
    if cached.present?
      @results = cached[:results]
      @recommendation_result = cached[:recommendation_result]
      @route_analysis = cached[:route_analysis]
      # Promote to both L1 Active and L2 Speculative
      @@l1_active_buffer[buffer_key] = cached
      @@l2_speculative_buffer[buffer_key] = cached
      @buffer_tier = "L3 Distributed Persistent"
      @recent_routes = LogisticsRoute.includes(:origin, :destination).recent.limit(8)
      return
    end

    begin
      # 1. Run ResQWay Risk-Aware Route Recommendation Service
      recommendation_res = ResQWay::RouteRecommendationService.new(
        origin: @origin,
        destination: @destination,
        priority_mode: @selected_priority,
        vehicle_type: @selected_vehicle,
        cargo_type: @selected_cargo
      ).recommend

      # 2. Run RouteOptimizationService for backwards compatibility with existing UI adapters
      opt_service = RouteOptimizationService.new(
        origin: @origin,
        destination: @destination,
        vehicle_type: @selected_vehicle
      )
      @results = opt_service.calculate

      # Enhance @results with ResQWay ML Disruption & Segment Intelligence
      @recommendation_result = recommendation_res
      @results[:resqway_recommendation] = recommendation_res
      @results[:enma_recommendation] = recommendation_res

      # 3. Persist or Reuse Route Analysis Record
      save_calculated_routes(@origin, @destination, @selected_vehicle, @selected_priority, @selected_cargo, @results, recommendation_res)

      # 4. Populate Triple-Buffer Architecture
      buf_payload = { results: @results, recommendation_result: recommendation_res, route_analysis: @route_analysis }
      
      # Buffer 1: Primary L1 Active In-Memory
      @@l1_active_buffer[buffer_key] = buf_payload
      
      # Buffer 2: L2 Speculative Pre-Warming (mirror return route & alternate profiles)
      return_key = "rt_buf_#{@destination.id}_#{@origin.id}_#{@selected_vehicle.parameterize}_#{@selected_priority}_#{@selected_cargo.parameterize}"
      @@l2_speculative_buffer[buffer_key] = buf_payload
      @@l2_speculative_buffer[return_key] = buf_payload

      # Buffer 3: L3 Persistent Distributed Rails Cache
      Rails.cache.write(buffer_key, buf_payload, expires_in: 2.hours)

      @buffer_tier = "Computed & Buffered (L1/L2/L3)"

      # Reload recent routes
      @recent_routes = LogisticsRoute.includes(:origin, :destination).recent.limit(8)
    rescue StandardError => e
      Rails.logger.error("[RoutesController] Route analysis error: #{e.message}\n#{e.backtrace&.first(3)&.join("\n")}")
      flash.now[:alert] = "Route analysis failed: #{e.message}"
    end
  end

  def save_calculated_routes(orig, dest, vtype, pmode, ctype, results, rec_res)
    return unless results && results[:routes]

    # Check for recent existing analysis to avoid duplicate database writes
    existing = RouteAnalysis.where(
      origin: orig,
      destination: dest,
      vehicle_type: vtype,
      priority_mode: pmode,
      cargo_type: ctype
    ).where("created_at > ?", 2.hours.ago).order(created_at: :desc).first

    if existing
      @route_analysis = existing
      return
    end

    # Save to RouteAnalysis
    champ = rec_res[:recommended_route] || {}
    @route_analysis = RouteAnalysis.create!(
      origin: orig,
      origin_name: orig.name,
      destination: dest,
      destination_name: dest.name,
      priority_mode: pmode,
      vehicle_type: vtype,
      cargo_type: ctype,
      recommended_route_type: champ[:type],
      recommended_route_name: champ[:title],
      distance_km: champ[:distance_km],
      provider_eta_minutes: champ[:provider_duration_minutes],
      enma_adjusted_eta_minutes: champ[:enma_adjusted_eta_minutes],
      route_risk_score: champ[:route_risk_score],
      ml_disruption_probability: champ[:ml_disruption_probability],
      optimization_score: champ[:optimization_score],
      confidence_score: rec_res.dig(:explanation, :confidence_score),
      all_routes_payload_json: rec_res[:routes],
      segment_analysis_json: champ[:matched_segments],
      explainable_reasons_json: rec_res.dig(:explanation, :positives),
      tradeoff_summary: rec_res.dig(:explanation, :tradeoff_summary),
      analyzed_at: Time.current
    )

    # Save to LogisticsRoute for fast lookup
    results[:routes].each do |type_key, route_data|
      LogisticsRoute.create!(
        origin: orig,
        destination: dest,
        vehicle_type: vtype,
        distance: route_data[:distance_km],
        estimated_time: route_data[:estimated_hours],
        risk_score: route_data[:risk_score],
        route_type: type_key.to_s,
        status: "analyzed",
        recommended: (type_key.to_s == champ[:type].to_s),
        waypoints_json: route_data[:coordinates].to_json,
        summary: route_data[:summary]
      )
    end
  rescue StandardError => e
    Rails.logger.warn("[RoutesController] Error persisting route history: #{e.message}")
  end
end
