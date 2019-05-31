require 'test_helper'

class UpdownTest < ActionDispatch::IntegrationTest
  setup do
    Updown.reset_storage!
    Mail::TestMailer.deliveries.clear
  end

  class HomepageTest < self
    test "homepage returns a list of servers with status" do
      get '/'
      assert_response :success
      Updown::DAEMONS.each do |ip, name|
        next if name == HOSTNAME
        s = Service.find_by(permalink: "daemon-#{name}")
        assert_select 'p.serviceList__name', s.name
      end
      assert_select 'span.serviceStatusTag', 'Operational'
    end
  end

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
  end

end