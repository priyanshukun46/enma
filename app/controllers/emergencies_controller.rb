class EmergenciesController < ApplicationController
  before_action :set_emergency, only: [:show, :update_status, :generate_plan, :export_briefing, :send_test_email]

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
      
      if @emergency.severity.to_s.casecmp?("critical")
        begin
          dispatch_emergency_email(@emergency)
        rescue StandardError => e
          Rails.logger.error("Failed to send critical emergency email alert: #{e.message}")
        end
      end
      
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
                  filename: "ResQWay_Response_Plan_#{@emergency.id}_#{Time.current.strftime('%Y%m%d_%H%M%S')}.txt",
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

  def send_test_email
    recipient = params[:email].presence || "pkfb46@proton.me"
    begin
      mode = dispatch_emergency_email(@emergency, recipient)
      if mode == :live_smtp
        flash[:notice] = "Critical Emergency Alert successfully emailed live via Gmail SMTP to #{recipient}."
      else
        flash[:notice] = "Test Email Alert dispatched for #{recipient} (saved to tmp/mails). To deliver live emails to your ProtonMail inbox, add GMAIL_SMTP_USERNAME and GMAIL_SMTP_APP_PASSWORD to .env."
      end
    rescue StandardError => e
      Rails.logger.error("Failed to send test email alert to #{recipient}: #{e.message}")
      flash[:alert] = "Failed to dispatch test email alert to #{recipient}: #{e.message}"
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

  def load_env_file_if_present
    env_file = Rails.root.join(".env")
    return unless File.exist?(env_file)

    File.foreach(env_file) do |line|
      line = line.strip
      next if line.empty? || line.start_with?("#")
      key, val = line.split("=", 2)
      ENV[key.strip] = val.to_s.strip.gsub(/\A["']|["']\z/, "") if key
    end
  end

  def dispatch_emergency_email(emergency, recipient = nil)
    load_env_file_if_present
    to_email = recipient.presence || "pkfb46@proton.me"
    mail = EmergencyAlertMailer.critical_alert(emergency, to_email)

    smtp_user = ENV["GMAIL_SMTP_USERNAME"].to_s.strip.presence
    smtp_pass = ENV["GMAIL_SMTP_APP_PASSWORD"].to_s.gsub(/\s+/, "").presence

    if smtp_user.present? && smtp_pass.present?
      mail.delivery_method(:smtp, {
        address: "smtp.gmail.com",
        port: 587,
        user_name: smtp_user,
        password: smtp_pass,
        authentication: "plain",
        enable_starttls_auto: true
      })
      mail.deliver_now
      :live_smtp
    else
      mail.delivery_method(:file, location: Rails.root.join("tmp/mails"))
      mail.deliver_now
      :saved_to_file
    end
  end
end
