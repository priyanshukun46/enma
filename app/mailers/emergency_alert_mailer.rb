class EmergencyAlertMailer < ApplicationMailer
  DEFAULT_RECIPIENT = "pkfb46@proton.me".freeze

  def critical_alert(emergency, recipient = nil)
    @emergency = emergency
    to_address = recipient.presence || ENV["RESQWAY_ALERT_RECIPIENT_EMAIL"].presence || DEFAULT_RECIPIENT
    from_address = ENV["GMAIL_SMTP_USERNAME"].to_s.strip.presence || "alerts@resqway.com"

    mail(
      from: from_address,
      to: to_address,
      subject: "ResQWay ALERT: #{@emergency.title} — #{@emergency.severity}"
    )
  end
end
