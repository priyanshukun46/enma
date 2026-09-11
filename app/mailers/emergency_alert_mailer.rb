class EmergencyAlertMailer < ApplicationMailer
  DEFAULT_RECIPIENT = "pkfb46@proton.me".freeze

  def critical_alert(emergency, recipient = nil)
    @emergency = emergency
    to_address = recipient.presence || ENV["RESQWAY_ALERT_RECIPIENT_EMAIL"].presence || DEFAULT_RECIPIENT

    mail(
      to: to_address,
      subject: "ResQWay ALERT: #{@emergency.title} — #{@emergency.severity}"
    )
  end
end
