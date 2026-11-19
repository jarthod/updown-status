source 'https://rubygems.org'
gem 'rails', '~> 8.1.0'
gem 'sqlite3'
gem 'sass-rails'
gem 'uglifier'
gem 'coffee-rails'
gem 'jquery-rails'
gem 'haml'
gem 'nifty-utils'
gem 'nilify_blanks'
gem 'authie'
gem 'kaminari'
gem 'chronic'
gem 'dynamic_form' # 1.3.x declares ruby < 3.4, so 1.2.0 is used (works fine with rails 8.1)
gem 'activevalidators'
gem 'bcrypt', '>= 3.1.12' # 3.1.11 fails on Ubuntu with HashError
gem 'rails_env_config'
gem 'chronic_duration'
gem 'datey'
gem 'nifty-attachments'
gem 'puma'
gem 'moonrope'
gem 'florrick'
gem 'delayed_job_active_record'
gem 'foreman'
gem 'redcarpet'
gem 'premailer'
gem 'mail' # sent with the mail gem directly (lib/staytus/email.rb), no Action Mailer
gem 'rack-custom-proxies'
gem 'log_logins'

group :development, :test do
  gem 'listen'
  gem 'annotaterb'
  gem 'webmock'
  gem 'capybara'
end

gem 'sassc'
gem 'vultr', '~> 1.0' # trigger vultr VM restarts, v2 looks like a big rewrite
gem 'ostruct' # needed by vultr 1.0, not a default gem anymore since ruby 4.0
gem 'rack-attack'
gem 'invisible_captcha'
gem 'minitest', '~> 5.0' # compatibility issue with Rails 7.2
gem 'json', '< 3' # json 3 breaks faraday 1.x used by vultr (positional options)
