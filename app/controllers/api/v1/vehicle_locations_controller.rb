module Api
  module V1
    class VehicleLocationsController < ActionController::API
      before_action :authenticate_request!

      def create
        service = Enma::GpsIngestionService.new(location_params)
        result = service.process

        if result[:success]
          render json: result, status: :created
        else
          render json: { error: result[:error] }, status: (result[:status] || :unprocessable_entity)
        end
      end

      private

      def authenticate_request!
        auth_header = request.headers["Authorization"]
        token = auth_header&.split(" ")&.last || params[:api_auth_token] || params[:token]

        if token.blank?
          render json: { error: "Authentication token required in Authorization header or payload" }, status: :unauthorized
          return
        end

        @current_vehicle = Vehicle.find_by(api_auth_token: token)
        unless @current_vehicle
          render json: { error: "Invalid API authorization token" }, status: :unauthorized
        end
      end

      def location_params
        params.permit(
          :vehicle_id,
          :shipment_id,
          :latitude,
          :longitude,
          :accuracy,
          :speed,
          :heading,
          :recorded_at,
          :source,
          :api_auth_token
        ).to_h.merge(vehicle_id: @current_vehicle&.id)
      end
    end
  end
end
