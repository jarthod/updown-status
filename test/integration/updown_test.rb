require_relative "../test_helper"

class UpdownTest < ActionDispatch::IntegrationTest
  class PingEndpointTest < self
    test "returns 403 if IP is not allowed" do
      get '/ping', headers: {'X-Forwarded-For' => '3.3.3.3'}
      assert_response :forbidden
    end

    test "register daemon check and returns 200" do
      assert_equal 1, Updown.last_checks[HOSTNAME].size
      get '/ping'
      assert_response :success
      assert_equal 2, Updown.last_checks[HOSTNAME].size
    end

    test "also accepts IPv6" do
      assert_equal 1, Updown.last_checks[HOSTNAME].size
      get '/ping', headers: {'X-Forwarded-For' => '::1'}
      assert_response :success
      assert_equal 2, Updown.last_checks[HOSTNAME].size
    end

    test "caps history at 20" do
      assert_equal 1, Updown.last_checks[HOSTNAME].size
      19.times { get '/ping' }
      assert_equal 20, Updown.last_checks[HOSTNAME].size
      5.times { get '/ping' }
      assert_equal 20, Updown.last_checks[HOSTNAME].size
    end

    test "marks daemon as up if was down" do
      assert_equal 0, Mail::TestMailer.deliveries.length
      Updown.status[HOSTNAME] = :down
      get '/ping'
      assert_equal :up, Updown.status[HOSTNAME]
      assert_equal 1, Mail::TestMailer.deliveries.length
    end

    test "marks global as up if was down" do
      assert_equal 0, Mail::TestMailer.deliveries.length
      Updown.status['global'] = :down
      get '/ping'
      assert_equal :up, Updown.status['global']
      assert_equal 1, Mail::TestMailer.deliveries.length
    end

    test "updates service status to operational" do
      srv = Service.create!(name: 'local', permalink: 'daemon-localhost-test', status_id: 4)
      assert_changes -> { srv.reload.status.permalink }, from: 'major-outage', to: 'operational' do
        get '/ping'
      end
    end
  end

  class SidekiqEndpointTest < self
    def payload queues: {default: 0, mailers: 0}
      {env: 'production', queues: queues}
    end

    test "returns 403 if IP is not allowed" do
      post '/sidekiq', params: payload, headers: {'X-Forwarded-For' => '3.3.3.3'}
      assert_response :forbidden
    end

    test "register sidekiq check and returns 200" do
      assert_equal Updown.last_sidekiq_ping[HOSTNAME].size, 1
      post '/sidekiq', params: payload
      assert_response :success
      assert_equal Updown.last_sidekiq_ping[HOSTNAME].size, 2
    end

    test "also accepts IPv6" do
      assert_equal Updown.last_sidekiq_ping[HOSTNAME].size, 1
      post '/sidekiq', params: payload, headers: {'X-Forwarded-For' => '::1'}
      assert_response :success
      assert_equal Updown.last_sidekiq_ping[HOSTNAME].size, 2
    end

    test "caps history at 20" do
      assert_equal Updown.last_sidekiq_ping[HOSTNAME].size, 1
      19.times { post '/sidekiq', params: payload }
      assert_equal Updown.last_sidekiq_ping[HOSTNAME].size, 20
      5.times { post '/sidekiq', params: payload }
      assert_equal Updown.last_sidekiq_ping[HOSTNAME].size, 20
    end

    test "marks daemon as up if was down" do
      assert_equal 0, Mail::TestMailer.deliveries.length
      Updown.sidekiq_status[HOSTNAME] = :down
      post '/sidekiq', params: payload
      assert_equal :up, Updown.sidekiq_status[HOSTNAME]
      assert_equal 1, Mail::TestMailer.deliveries.length
    end

    test "don't consider missing queue as unhealthy" do
      post '/sidekiq', params: payload(queues: {default: 100})
      assert_equal :up, Updown.sidekiq_status[HOSTNAME]
    end

    test "marks daemon as down if unhealthy" do
      assert_equal 0, Mail::TestMailer.deliveries.length
      post '/sidekiq', params: payload(queues: {default: 5000, mailers: 0})
      assert_equal :down, Updown.sidekiq_status[HOSTNAME]
      assert_equal 1, Mail::TestMailer.deliveries.length
      assert_includes Mail::TestMailer.deliveries.first.body.encoded, 'localhost-test sidekiq queue too big: {"default":"5000","mailers":"0"}'
    end

    test "marks daemon as down if low queue is high" do
      assert_equal 0, Mail::TestMailer.deliveries.length
      post '/sidekiq', params: payload(queues: {default: 5, mailers: 1, low: 10000})
      assert_equal :down, Updown.sidekiq_status[HOSTNAME]
      assert_equal 1, Mail::TestMailer.deliveries.length
    end

    test "marks daemon as down if missing numbers" do
      assert_equal 0, Mail::TestMailer.deliveries.length
      post '/sidekiq', params: payload(queues: nil)
      assert_equal :down, Updown.sidekiq_status[HOSTNAME]
      assert_equal 1, Mail::TestMailer.deliveries.length
    end

    test "marks service as partial outage if unhealthy" do
      srv = Service.create!(name: 'local', permalink: 'daemon-localhost-test', status_id: 1)
      assert_changes -> { srv.reload.status.permalink }, from: 'operational', to: 'partial-outage' do
        post '/sidekiq', params: payload(queues: {default: 5000, mailers: 0})
      end
      assert_equal 'operational', services(:daemon_syd).status.permalink
    end

    test "marks service as partial outage low queue is high" do
      srv = Service.create!(name: 'local', permalink: 'daemon-localhost-test', status_id: 1)
      assert_changes -> { srv.reload.status.permalink }, from: 'operational', to: 'partial-outage' do
        post '/sidekiq', params: payload(queues: {default: 5, mailers: 1, low: 10000})
      end
      assert_equal 'operational', services(:daemon_syd).status.permalink
    end

    test "marks service as partial outage if missing numbers" do
      srv = Service.create!(name: 'local', permalink: 'daemon-localhost-test', status_id: 1)
      assert_changes -> { srv.reload.status.permalink }, from: 'operational', to: 'partial-outage' do
        post '/sidekiq', params: payload(queues: nil)
      end
      assert_equal 'operational', services(:daemon_syd).status.permalink
    end

    test "does nothing if it stays down" do
      assert_equal 0, Mail::TestMailer.deliveries.length
      Updown.sidekiq_status[HOSTNAME] = :down
      post '/sidekiq', params: payload(queues: nil)
      assert_equal :down, Updown.sidekiq_status[HOSTNAME]
      assert_equal 0, Mail::TestMailer.deliveries.length
    end
  end

  class CheckStatusTest < self
    def teardown
      ENV.delete("VULTR_API_KEY")
    end

    test "does nothing if all is good" do
      assert_equal 0, Mail::TestMailer.deliveries.length
      assert_equal :up, Updown.sidekiq_status[HOSTNAME]
      assert_equal :up, Updown.status[HOSTNAME]
      assert_equal :up, Updown.status['global']
      Updown.check_status
      assert_equal :up, Updown.sidekiq_status[HOSTNAME]
      assert_equal :up, Updown.status[HOSTNAME]
      assert_equal :up, Updown.status['global']
      assert_equal 0, Mail::TestMailer.deliveries.length
    end

    test "mark one host down if no check in more than 1 hour" do
      assert_equal 0, Mail::TestMailer.deliveries.length
      assert_equal :up, Updown.status[HOSTNAME]
      Updown.last_checks[HOSTNAME].unshift Time.now - 3601
      Updown.check_status
      assert_equal :down, Updown.status[HOSTNAME]
      assert_equal 1, Mail::TestMailer.deliveries.length
    end

    test "attempts a Vultr restart if no check in more than 1 hour" do
      ENV["VULTR_API_KEY"] = "test"
      stub_request(:get, "https://api.vultr.com/v2/instances").with(headers: { 'Authorization'=>'Bearer test' }).to_return(status: 200, headers: {'content-type' => 'application/json'}, body: '{"instances":[{"id":"2987e294-0b5f-47f7-b025-3cdc1062ae05","main_ip":"45.76.104.117","status":"active","power_status":"running","server_status":"ok","label":"localhost-test.updn.io","hostname":"localhost-test.updn.io"}],"meta":{"total":1,"links":{"next":"","prev":""}}}')
      stub_request(:post, "https://api.vultr.com/v2/instances/2987e294-0b5f-47f7-b025-3cdc1062ae05/reboot").with(body: "{}", headers: {'Authorization'=>'Bearer test'}).to_return(status: [204, 'No Content'])
      assert_equal :up, Updown.status[HOSTNAME]
      Updown.last_checks[HOSTNAME].unshift Time.now - 3601
      Updown.check_status
      assert_equal :down, Updown.status[HOSTNAME]
      assert_includes Mail::TestMailer.deliveries.first.body.encoded, "Found matching Vultr instance localhost-test.updn.io (2987e294-0b5f-47f7-b025-3cdc1062ae05), rebooting..."
      assert_includes Mail::TestMailer.deliveries.first.body.encoded, "Reboot command response: 204 No Content"
    end

    test "skips Vultr restart if machine is not in Vultr" do
      ENV["VULTR_API_KEY"] = "test"
      stub_request(:get, "https://api.vultr.com/v2/instances").with(headers: { 'Authorization'=>'Bearer test' }).to_return(status: 200, headers: {'content-type' => 'application/json'}, body: '{"instances":[{"id":"2987e294-0b5f-47f7-b025-3cdc1062ae05","main_ip":"45.76.104.117","status":"active","power_status":"running","server_status":"ok","label":"tok.updn.io","hostname":"tok.updn.io"}],"meta":{"total":1,"links":{"next":"","prev":""}}}')
      stub_request(:post, "https://api.vultr.com/v2/instances/2987e294-0b5f-47f7-b025-3cdc1062ae05/reboot").with(body: "{}", headers: {'Authorization'=>'Bearer test'}).to_return(status: [204, 'No Content'])
      assert_equal :up, Updown.status[HOSTNAME]
      Updown.last_checks[HOSTNAME].unshift Time.now - 3601
      Updown.check_status
      assert_equal :down, Updown.status[HOSTNAME]
      assert_includes Mail::TestMailer.deliveries.first.body.encoded, "No Vultr instance found with hostname=localhost-test.updn.io"
    end

    test "mark global down if no check in more than 5 minutes" do
      assert_equal 0, Mail::TestMailer.deliveries.length
      assert_equal :up, Updown.status['global']
      Updown::DAEMONS.each { |ip, hostname| Updown.last_checks[hostname].unshift Time.now - 305 }
      Updown.check_status
      assert_equal :down, Updown.status['global']
      assert_equal 1, Mail::TestMailer.deliveries.length
    end

    test "updates one service status to major outage if no check in more than 1 hour" do
      srv = Service.create!(name: 'local', permalink: 'daemon-localhost-test', status_id: 1)
      assert_changes -> { srv.reload.status.permalink }, from: 'operational', to: 'major-outage' do
        Updown.last_checks[HOSTNAME].unshift Time.now - 3601
        Updown.check_status
      end
      assert_equal 'operational', services(:daemon_syd).status.permalink
    end

    test "updates all service status to major outage if no check in more than 5 minutes" do
      srv = services(:daemon_syd)
      assert_changes -> { srv.reload.status.permalink }, from: 'operational', to: 'major-outage' do
        Updown::DAEMONS.each { |ip, hostname| Updown.last_checks[hostname].unshift Time.now - 305 }
        Updown.check_status
      end
    end

    test "do not update status for service with ongoing issue" do
      srv = services(:daemon_syd)
      Issue.create!(services: [srv], title: "ongoing issue", state: 'identified', service_status_id: 3, user: users(:adrien))
      assert_no_changes -> { srv.reload.status.permalink }, from: 'partial-outage' do
        Updown::DAEMONS.each { |ip, hostname| Updown.last_checks[hostname].unshift Time.now - 305 }
        Updown.check_status
      end
    end
  end

  class CheckPostmarkTest < self
    test "does nothing if all is good" do
      srv = services(:email_notifications)
      stub_request(:get, "https://status.postmarkapp.com/api/v1/components").to_return(body: '{"components":[{"id":46327,"name":"API","description":null,"state":"operational","parent_id":null,"position":1,"created_at":"2022-12-17T17:54:22.245Z","updated_at":"2023-02-18T01:21:20.546Z"},{"id":46328,"name":"SMTP (sending)","description":null,"state":"operational","parent_id":null,"position":2,"created_at":"2022-12-17T17:54:34.094Z","updated_at":"2023-02-18T01:21:20.546Z"},{"id":46329,"name":"SMTP (receiving)","description":null,"state":"operational","parent_id":null,"position":3,"created_at":"2022-12-17T17:54:51.401Z","updated_at":"2023-02-18T01:21:20.546Z"},{"id":46330,"name":"Web App","description":null,"state":"operational","parent_id":null,"position":4,"created_at":"2022-12-17T17:55:00.197Z","updated_at":"2023-02-18T01:21:20.546Z"}],"meta":{"count":4,"total_count":4}}')
      assert_no_changes -> { srv.reload.status.permalink }, from: 'operational' do
        Updown.check_postmark
      end
    end

    test "updates service status if postmark API is degraded" do
      srv = services(:email_notifications)
      stub_request(:get, "https://status.postmarkapp.com/api/v1/components").to_return(body: '{"components":[{"id":46327,"name":"API","state":"degraded"},{"id":46328,"name":"SMTP (sending)","state":"under_maintenance"}]}')
      assert_changes -> { srv.reload.status.permalink }, from: 'operational', to: 'partial-outage' do
        Updown.check_postmark
      end
    end

    test "updates service status if postmark SMTP is degraded" do
      srv = services(:email_notifications)
      stub_request(:get, "https://status.postmarkapp.com/api/v1/components").to_return(body: '{"components":[{"id":46327,"name":"API","state":"operational"},{"id":46328,"name":"SMTP (sending)","state":"degraded"}]}')
      assert_changes -> { srv.reload.status.permalink }, from: 'operational', to: 'degraded-performance' do
        Updown.check_postmark
      end
    end

    test "updates service status if postmark is in maintenance" do
      srv = services(:email_notifications)
      stub_request(:get, "https://status.postmarkapp.com/api/v1/components").to_return(body: '{"components":[{"id":46327,"name":"API","state":"under_maintenance"},{"id":46328,"name":"SMTP (sending)","state":"operational"}]}')
      assert_changes -> { srv.reload.status.permalink }, from: 'operational', to: 'maintenance' do
        Updown.check_postmark
      end
    end
  end

  class CheckWebUrlsTest < self
    test "does nothing if all is good" do
      services = [services(:web), services(:api), services(:custom_status_pages)]
      stub_request(:head, "https://updown.io/users/sign_in")
      stub_request(:head, "https://updown.io/api/checks/ngg8?api-key=ro-ilx4voqgu8l8bxqu0tld")
      stub_request(:head, "https://meta.updown.io")
      assert_no_changes -> {
        services.map {|srv| srv.reload.status.permalink }
      }, from: ['operational', 'operational', 'operational'] do
        Updown.check_web_urls
      end
    end

    test "updates service to major outage if 500" do
      srv = services(:web)
      stub_request(:head, "https://updown.io").to_return(status: 500)
      assert_changes -> { srv.reload.status.permalink }, from: 'operational', to: 'major-outage' do
        Updown.check_web_url srv, "https://updown.io"
      end
    end

    test "updates service to maintenance if 503" do
      srv = services(:web)
      stub_request(:head, "https://updown.io").to_return(status: 503)
      assert_changes -> { srv.reload.status.permalink }, from: 'operational', to: 'maintenance' do
        Updown.check_web_url srv, "https://updown.io"
      end
    end

    test "updates service to degraded-performance if slow" do
      srv = services(:web)
      stub_request(:head, "https://updown.io").to_return(status: 200)
      assert_changes -> { srv.reload.status.permalink }, from: 'operational', to: 'degraded-performance' do
        Updown.check_web_url srv, "https://updown.io", ok_time: 0
      end
    end

    test "updates service to major outage if timeout" do
      srv = services(:web)
      stub_request(:head, "https://updown.io").to_timeout
      assert_changes -> { srv.reload.status.permalink }, from: 'operational', to: 'major-outage' do
        Updown.check_web_url srv, "https://updown.io"
      end
    end
  end
end
