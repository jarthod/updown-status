module Staytus
  module Config
    class << self

      def theme_name
        ENV['STAYTUS_THEME'] || 'default'
      end

      def theme_root
        ENV['STAYTUS_THEME_ROOT'] ? File.join(ENV['STAYTUS_THEME_ROOT'], self.theme_name) : Rails.root.join('content', 'themes', self.theme_name)
      end

      def version
        '1.3.2'
      end

      def demo?
        ENV['STAYTUS_DEMO'] == '1'
      end

    end
  end
end
