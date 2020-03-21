require_relative "../test_helper"

class HomepageTest < ActionDispatch::IntegrationTest
  test "homepage returns a list of servers with status" do
    visit '/'
    Updown::DAEMONS.each do |ip, name|
      next if name == HOSTNAME
      s = Service.find_by(permalink: "daemon-#{name}")
      assert_css 'p.serviceList__name', text: s.name
    end
    assert_css 'span.serviceStatusTag', text: 'Operational'
  end
end