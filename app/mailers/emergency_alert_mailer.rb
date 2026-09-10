class EmergencyAlertMailer < ApplicationMailer
  def critical_alert(emergency)
    @emergency = emergency
    recipient = ENV["RESQWAY_ALERT_RECIPIENT_EMAIL"]

    if recipient.blank?
      Rails.logger.warn("EmergencyAlertMailer: RESQWAY_ALERT_RECIPIENT_EMAIL is not set. Skipping email.")
      return
    end

    mail(
      to: recipient,
      subject: "ResQWay ALERT: #{@emergency.title} — #{@emergency.severity}"
    )
  end
end
