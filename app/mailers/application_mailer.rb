class ApplicationMailer < ActionMailer::Base
  default from: ENV["GMAIL_SMTP_USERNAME"] || "alerts@resqway.com"
  layout "mailer"
end
