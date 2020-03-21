require 'staytus/version'

module Staytus
  module Config
    class << self

      def version
        Staytus::VERSION
      end

      def demo?
        ENV['STAYTUS_DEMO'] == '1'
      end

    end
  end
end
