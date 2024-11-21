ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'
require 'webmock/minitest'
require 'capybara/rails'
require 'capybara/minitest'

HOSTNAME = 'localhost-test'
Updown::DAEMONS['127.0.0.1'] = HOSTNAME
Updown::WORKERS['127.0.0.1'] = HOSTNAME
Updown::DAEMONS['::1'] = HOSTNAME
Updown::WORKERS['::1'] = HOSTNAME
Mail.defaults { delivery_method :test }

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  setup do
    Updown.reset_storage!
    Mail::TestMailer.deliveries.clear
  end
end

class ActionDispatch::IntegrationTest
  # Make the Capybara DSL available in all integration tests
  include Capybara::DSL
  # Make `assert_*` methods behave like Minitest assertions
  include Capybara::Minitest::Assertions

  # Reset sessions and driver between tests
  teardown do
    Capybara.reset_sessions!
    Capybara.use_default_driver
    # Rack::Attack.reset!
  end
end
