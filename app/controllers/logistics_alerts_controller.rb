class LogisticsAlertsController < ApplicationController
  def index
    @alerts = LogisticsAlert.includes(:vehicle, :shipment).recent
    @active_alerts = @alerts.active
    @critical_count = @active_alerts.where(severity: "critical").count
    @high_count = @active_alerts.where(severity: "high").count
    @warning_count = @active_alerts.where(severity: "warning").count
  end

  def acknowledge
    @alert = LogisticsAlert.find(params[:id])
    @alert.update(status: "acknowledged")
    redirect_back fallback_location: logistics_alerts_path, notice: "Alert marked as acknowledged."
  end

  def resolve
    @alert = LogisticsAlert.find(params[:id])
    @alert.update(status: "resolved")
    redirect_back fallback_location: logistics_alerts_path, notice: "Alert marked as resolved."
  end
end
