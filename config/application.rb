require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Staytus
  class Application < Rails::Application
    config.eager_load_paths += %W(#{config.root}/lib)
    config.generators do |g|
      g.orm             :active_record
      g.test_framework  false
      g.stylesheets     false
      g.javascripts     false
      g.helper          false
    end
    config.active_record.sqlite3.represent_boolean_as_integer = true
    config.i18n.load_path += Dir[Rails.root.join('content', 'locales', '*.{rb,yml}').to_s]
  end
end
