class EmergenciesController < ApplicationController
  before_action :set_emergency, only: [:show, :update_status, :generate_plan, :export_briefing]

  def index
    @status_filter = params[:status].presence || "all"
    
    base_scope = case @status_filter
                 when "active" then Emergency.active.recent
                 when "monitoring" then Emergency.monitoring.recent
                 when "responding" then Emergency.responding.recent
                 when "resolved" then Emergency.resolved.recent
                 else Emergency.recent
                 end.includes(:location)
    @pagy, @emergencies = pagy(base_scope)

    @total_emergencies = Emergency.count
    @active_count = Emergency.active_or_responding.count
    @critical_count = Emergency.critical.active_or_responding.count
    @resolved_count = Emergency.resolved.count
  end

  def new
    @emergency = Emergency.new(
      affected_radius: 50.0,
      severity: "Critical",
      emergency_type: "Landslide",
      status: "Active"
    )
    @locations = Location.order(:name)
  end

  def create
    @emergency = Emergency.new(emergency_params)
    @emergency.status ||= "Active"
    @emergency.simulated_at ||= Time.current

    # If location_id is provided, populate latitude/longitude if empty
    if @emergency.location_id.present?
      loc = Location.find_by(id: @emergency.location_id)
      if loc
        @emergency.latitude ||= loc.latitude
        @emergency.longitude ||= loc.longitude
        @emergency.title = "Emergency near #{loc.name}" if @emergency.title.blank?
      end
    end

    if @emergency.save
      @emergency.generate_response_plan!
      flash[:notice] = "Emergency scenario successfully initialized & automated AI Response Plan generated."
      redirect_to emergency_path(@emergency)
    else
      @locations = Location.order(:name)
      flash.now[:alert] = @emergency.errors.full_messages.join(", ")
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @analysis = @emergency.response_analysis
    @response_plan = @emergency.latest_response_plan || @emergency.generate_response_plan!
  end

  def generate_plan
    @response_plan = @emergency.generate_response_plan!
    flash[:notice] = "⚡ AI Response Plan regenerated and updated with real-time intelligence."
    redirect_to emergency_path(@emergency)
  end

  def export_briefing
    @response_plan = @emergency.latest_response_plan || @emergency.generate_response_plan!
    respond_to do |format|
      format.text { render plain: @response_plan.formatted_briefing }
      format.json { render json: @response_plan.plan_payload }
      format.html do
        send_data @response_plan.formatted_briefing,
                  filename: "ENMA_AI_Response_Plan_#{@emergency.id}_#{Time.current.strftime('%Y%m%d_%H%M%S')}.txt",
                  type: "text/plain"
      end
    end
  end

  def update_status
    new_status = params[:status]
    if %w[Active Monitoring Responding Resolved].include?(new_status)
      @emergency.update!(status: new_status)
      flash[:notice] = "Emergency status updated to #{new_status}."
    else
      flash[:alert] = "Invalid status specified."
    end
    redirect_to emergency_path(@emergency)
  end

  def demo_scenario
    # Create or update realistic SIH demonstration scenario (Heavy Rainfall -> Critical Landslide near Tawang)
    tawang = Location.find_by(name: "Tawang") || Location.first

    demo_emergency = Emergency.create!(
      title: "Major Monsoon Landslide & Flash Cutoff near Tawang",
      emergency_type: "Landslide",
      severity: "Critical",
      latitude: tawang ? tawang.latitude : 27.5855,
      longitude: tawang ? tawang.longitude : 91.8679,
      affected_radius: 50.0,
      status: "Active",
      location: tawang,
      simulated_at: Time.current,
      description: "Torrential monsoon cloudburst triggered severe slope failure blocking arterial NH-13/NH-229 corridor. Multiple highland villages isolated with immediate relief supply deficit."
    )

    # Generate full Response Plan automatically
    demo_emergency.generate_response_plan!

    flash[:notice] = "⚡ SIH 2026 Demo Scenario Activated: Critical Landslide near Tawang simulated & AI Response Plan generated successfully."
    redirect_to emergency_path(demo_emergency)
  end

  private

  def set_emergency
    @emergency = Emergency.find(params[:id])
  end

  def emergency_params
    params.require(:emergency).permit(
      :title,
      :emergency_type,
      :severity,
      :latitude,
      :longitude,
      :affected_radius,
      :status,
      :description,
      :location_id
    )
  end
end
