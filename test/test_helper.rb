ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'
require 'webmock/minitest'

HOSTNAME = 'localhost-test'
Updown::DAEMONS['127.0.0.1'] = HOSTNAME
Updown::WORKERS['127.0.0.1'] = HOSTNAME
Mail.defaults { delivery_method :test }

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...
end
