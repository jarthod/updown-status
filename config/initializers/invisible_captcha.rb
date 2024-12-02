InvisibleCaptcha.setup do |config|
  # config.honeypots           << ['more', 'fake', 'attribute', 'names']
  # config.visual_honeypots    = true
  # config.timestamp_threshold = 4
  config.timestamp_enabled     = !Rails.env.test?
  # config.injectable_styles   = false
  # config.spinner_enabled     = true

  # derive a consistent key across instances, based on secret_key_base
  config.secret = Rails.application.key_generator.generate_key('invisible_captcha')
end
