if ENV['STAYTUS_SMTP_HOSTNAME']
  smtp_settings = {
    :address                => ENV['STAYTUS_SMTP_HOSTNAME'],
    :port                   => ENV['STAYTUS_SMTP_PORT'],
    :user_name              => ENV['STAYTUS_SMTP_USERNAME'],
    :password               => ENV['STAYTUS_SMTP_PASSWORD'],
    :authentication         => ENV['STAYTUS_SMTP_AUTH_MODE'],
    :enable_starttls_auto   => ENV['STAYTUS_SMTP_STARTTLS'] == '1'
  }
  Mail.defaults { delivery_method :smtp, smtp_settings }
else
  puts "\e[33m=> You haven't configured an SMTP server. Mail will be sent using sendmail.\e[0m"
  Mail.defaults { delivery_method :sendmail }
end
