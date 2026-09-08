class IncidentsController < ApplicationController
  before_action :require_authentication, only: [:new, :create]
  before_action :set_incident, only: [:show]

  def index
    @incidents_scope = Incident.includes(:user, photos_attachments: :blob)

    if params[:incident_type].present? && params[:incident_type] != "all"
      @incidents_scope = @incidents_scope.by_type(params[:incident_type])
    end

    if params[:severity].present? && params[:severity] != "all"
      @incidents_scope = @incidents_scope.by_severity(params[:severity])
    end

    if params[:status].present? && params[:status] != "all"
      @incidents_scope = @incidents_scope.by_status(params[:status])
    end

    @total_count = Incident.count
    @reported_count = Incident.where(status: "reported").count
    @verified_count = Incident.where(status: "verified").count
    @resolved_count = Incident.where(status: "resolved").count
    @critical_count = Incident.critical.count

    respond_to do |format|
      format.html do
        @pagy, @incidents = pagy(@incidents_scope.recent)
      end
      format.json do
        @incidents = @incidents_scope.recent.limit(200)
        render json: @incidents.map { |inc| inc.as_map_json(view_context) }
      end
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json do
        render json: @incident.as_map_json(view_context)
      end
    end
  end

  def new
    @incident = Incident.new(
      reported_at: Time.current,
      severity: params[:severity].presence || "medium",
      incident_type: params[:type].presence || "landslide"
    )
  end

  def create
    @incident = Incident.new(incident_params)
    @incident.user = current_user
    @incident.reported_at ||= Time.current
    @incident.status ||= "reported"

    if @incident.save
      begin
        Enma::DataConfidenceService.new(@incident).calculate_and_save!
      rescue StandardError => e
        Rails.logger.error("Data confidence evaluation failed for incident #{@incident.id}: #{e.message}")
      end
      redirect_to incident_path(@incident), notice: "Field incident report submitted successfully. Geographic intelligence updated."
    else
      flash.now[:alert] = "Please fix the errors below to submit the incident report."
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_incident
    @incident = Incident.find(params[:id])
  end

  def incident_params
    params.require(:incident).permit(
      :incident_type,
      :severity,
      :description,
      :latitude,
      :longitude,
      :location_name,
      :district,
      :state,
      :reported_at,
      photos: []
    )
  end
end
