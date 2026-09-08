module ResQWay
  class GpsIngestionService
    attr_reader :params, :vehicle, :shipment

    def initialize(params)
      @params = params.with_indifferent_access
    end

    def process
      # 1. Resolve vehicle
      find_vehicle
      return { success: false, error: "Vehicle not found or unauthorized", status: :unauthorized } unless vehicle

      # 2. Extract & Validate Coordinates
      lat = params[:latitude].to_f
      lon = params[:longitude].to_f
      return { success: false, error: "Invalid coordinates", status: :unprocessable_entity } unless valid_coordinates?(lat, lon)

      recorded_at = parse_recorded_at(params[:recorded_at])
      speed = params[:speed].to_f
      heading = params[:heading].to_f
      accuracy = params[:accuracy].to_f
      source = params[:source].presence || "mobile"

      # 3. Find Active Shipment
      @shipment = resolve_shipment

      ActiveRecord::Base.transaction do
        # 4. Store GPS Location History
        loc = VehicleLocation.create!(
          vehicle: vehicle,
          shipment: shipment,
          latitude: lat,
          longitude: lon,
          speed: speed,
          heading: heading,
          accuracy: accuracy,
          recorded_at: recorded_at,
          source: source,
          raw_payload_json: params
        )

        # 5. Update Vehicle Position & Telemetry
        vehicle.update_position_from_gps!(
          lat, lon,
          speed: speed,
          heading: heading,
          recorded_at: recorded_at
        )

        # 6. Run Shipment Intelligence
        if shipment
          process_shipment_intelligence(lat, lon, speed, recorded_at)
        end

        {
          success: true,
          vehicle_id: vehicle.id,
          registration_number: vehicle.registration_number,
          shipment_id: shipment&.id,
          tracking_number: shipment&.tracking_number,
          progress_percentage: shipment&.progress_percentage,
          enma_adjusted_eta: shipment&.enma_adjusted_eta,
          delay_minutes: shipment&.delay_minutes,
          status: :created
        }
      end
    rescue StandardError => e
      Rails.logger.error("[GpsIngestionService] Error ingesting GPS: #{e.message}\n#{e.backtrace&.first(3)&.join("\n")}")
      { success: false, error: e.message, status: :internal_server_error }
    end

    private

    def find_vehicle
      if params[:api_auth_token].present?
        @vehicle = Vehicle.find_by(api_auth_token: params[:api_auth_token])
      elsif params[:vehicle_id].present?
        @vehicle = Vehicle.find_by(id: params[:vehicle_id]) || Vehicle.find_by(registration_number: params[:vehicle_id])
      end
    end

    def resolve_shipment
      if params[:shipment_id].present?
        Shipment.find_by(id: params[:shipment_id]) || Shipment.find_by(tracking_number: params[:shipment_id])
      else
        vehicle.active_shipment
      end
    end

    def valid_coordinates?(lat, lon)
      lat.between?(-90.0, 90.0) && lon.between?(-180.0, 180.0) && !(lat.zero? && lon.zero?)
    end

    def parse_recorded_at(val)
      return Time.current if val.blank?
      Time.zone.parse(val.to_s) rescue Time.current
    end

    def process_shipment_intelligence(lat, lon, speed, recorded_at)
      # A. Calculate Delivery Progress
      progress_data = DeliveryProgressService.new(
        shipment: shipment,
        current_lat: lat,
        current_lon: lon
      ).calculate

      # B. Detect Route Deviation
      dev_data = RouteDeviationService.new(
        shipment: shipment,
        current_lat: lat,
        current_lon: lon
      ).evaluate

      # C. Corridor & Road Risk Monitoring
      risk_data = CorridorRiskMonitorService.new(
        vehicle: vehicle,
        shipment: shipment,
        current_lat: lat,
        current_lon: lon
      ).evaluate

      # D. Calculate ETA Intelligence
      eta_data = EtaIntelligenceService.new(
        shipment: shipment,
        current_speed: speed,
        remaining_distance_km: progress_data[:remaining_distance_km],
        corridor_risk: risk_data[:road_risk_score],
        ml_disruption_prob: risk_data[:ml_disruption_probability],
        incident_count: risk_data[:nearby_incident].present? ? 1 : 0
      ).calculate

      # E. Update Status if Delivered or Delayed
      new_status = shipment.status
      if progress_data[:progress_percentage] >= 98.0 || progress_data[:remaining_distance_km] <= 0.8
        new_status = "delivered"
        vehicle.update_column(:status, "available")
      elsif dev_data[:deviation_detected]
        new_status = "delayed" if new_status == "in_transit"
        create_deviation_alert(dev_data[:deviation_distance_meters], lat, lon)
      elsif eta_data[:delay_minutes] >= 25
        new_status = "delayed" if new_status == "in_transit"
      elsif new_status == "planned" || new_status == "assigned"
        new_status = "in_transit"
        vehicle.update_column(:status, "in_transit")
      end

      # F. Persist updated Shipment Telemetry
      shipment.update_columns(
        status: new_status,
        progress_percentage: progress_data[:progress_percentage],
        distance_traveled_km: progress_data[:distance_traveled_km],
        total_distance_km: progress_data[:total_distance_km],
        provider_planned_eta: eta_data[:provider_planned_eta],
        current_estimated_eta: eta_data[:current_estimated_eta],
        enma_adjusted_eta: eta_data[:enma_adjusted_eta],
        delay_minutes: eta_data[:delay_minutes],
        current_corridor_risk: risk_data[:road_risk_score],
        ml_disruption_probability: risk_data[:ml_disruption_probability],
        deviation_detected: dev_data[:deviation_detected],
        deviation_distance_meters: dev_data[:deviation_distance_meters],
        actual_departure: shipment.actual_departure || recorded_at
      )
    end

    def create_deviation_alert(dev_meters, lat, lon)
      dedup_key = "deviation_#{shipment.id}_#{Time.current.strftime('%Y%m%d%H')}"
      return if LogisticsAlert.where(dedup_key: dedup_key).exists?

      LogisticsAlert.create!(
        vehicle: vehicle,
        shipment: shipment,
        alert_type: "route_deviation",
        severity: dev_meters > 2000 ? "critical" : "warning",
        title: "⚠️ Route Deviation Detected: #{vehicle.registration_number}",
        message: "Vehicle deviated #{dev_meters.round(0)}m from the planned logistics highway corridor.",
        location_name: "Off-Route Track",
        latitude: lat,
        longitude: lon,
        recommended_action: "Contact driver or dispatcher to verify detour reason and route integrity.",
        dedup_key: dedup_key
      )
    end
  end
end
