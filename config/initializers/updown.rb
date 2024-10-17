require 'net/http'
require 'json'

Authie.config.session_inactivity_timeout = 12.months

module Updown
  DAEMONS = {
    '45.32.74.41' => 'lan',
    '2001:19f0:6001:2c6::1' => 'lan',
    '104.238.136.194' => 'mia',
    '2001:19f0:9002:11a::1' => 'mia',
    '192.99.37.47' => 'bhs',
    '2607:5300:60:4c2f::1' => 'bhs',
    '91.121.222.175' => 'rbx',
    '2001:41d0:2:85af::1' => 'rbx',
    '104.238.159.87' => 'fra',
    '2001:19f0:6c01:145::1' => 'fra',
    '135.181.102.135' => 'hel',
    '2a01:4f9:c010:d5f9::1' => 'hel',
    '45.32.107.181' => 'sin',
    '2001:19f0:4400:402e::1' => 'sin',
    '45.76.104.117' => 'tok',
    '2001:19f0:7001:45a::1' => 'tok',
    '45.63.29.207' => 'syd',
    '2001:19f0:5801:1d8::1' => 'syd',
  }

  WEB = {
    '178.63.21.176' => 'db3',
    '2a01:4f8:141:441a::2' => 'db3',
    '91.121.222.175' => 'rbx',
    '2001:41d0:2:85af::1' => 'rbx',
  }

  WORKERS = WEB.merge(DAEMONS)
  REFRESH_RATE = 60 # sec

  mattr_accessor :last_checks, :status, :sidekiq_status, :last_sidekiq_ping, :disabled_locations

  def self.notify title, body
    return if Rails.env.development?
    Mail.deliver do
      from    "monitor@updown.io"
      to      "bigbourin@gmail.com"
      subject "[updown status] #{title}"
      body    "#{body}\n—\n#{Updown.text_recap}\n—\n#{Time.new}\nhttps://status.updown.io"
      content_type "text/plain; charset=UTF-8"
    end
  end

  def self.reset_storage!
    @@last_checks = Hash.new { |h, k| h[k] = [Time.now] }
    @@last_sidekiq_ping = Hash.new { |h, k| h[k] = [Time.now] }
    @@status = Hash.new { |h, k| h[k] = :up }
    @@sidekiq_status = Hash.new { |h, k| h[k] = :up }
    @@disabled_locations = []
  end

  def self.attempt_instance_reboot(name)
    logger = StringIO.new
    hostname = "#{name}.updn.io"
    return if ENV["VULTR_API_KEY"].nil?
    client = Vultr::Client.new(api_key: ENV["VULTR_API_KEY"])
    instances = client.instances.list
    instance = instances.data.find { |i| i.hostname == "#{name}.updn.io" }
    if instance
      logger.puts(msg = "Found matching Vultr instance #{instance.hostname} (#{instance.id}), rebooting...")
      Rails.logger.info(msg)
      response = client.instances.reboot(instance_id: instance.id)
      logger.puts(msg = "Reboot command response: #{response.status} #{response.reason_phrase} #{response.body}")
      Rails.logger.info(msg)
    else
      logger.puts(msg = "No Vultr instance found with hostname=#{hostname}")
      Rails.logger.info(msg)
    end
    logger
  rescue => e
    Rails.logger.warn "[updown] Instance reboot failed: #{e.class}: #{e.message}"
    logger.puts "Instance reboot failed: #{e.class}: #{e.message}"
    logger
  end

  def self.check_status
    last_diff = Float::INFINITY
    alerts = []
    DAEMONS.each do |ip, name|
      if @@last_checks[name].first
        diff = Time.now - @@last_checks[name].first
        last_diff = diff if diff < last_diff
        if diff > 3600 and @@status[name] == :up
          alerts << "#{name.upcase} has stopped monitoring 1h ago"
          if @@disabled_locations.include?(name)
            alerts << "→ Manually disabled (https://updown.io/admin/ops)"
          else
            alerts << attempt_instance_reboot(name)&.string&.chomp
          end
          @@status[name] = :down
        end
      end
    end
    if last_diff > 300 and @@status['global'] == :up
      alerts << "🔥 No request received for 5m"
      @@status['global'] = :down
    end
    WORKERS.each do |ip, name|
      if @@last_sidekiq_ping[name].first
        diff = Time.now - @@last_sidekiq_ping[name].first
        if diff > 300 and @@sidekiq_status[name] == :up
          alerts << "#{name.upcase} sidekiq stopped working 5m ago"
          @@sidekiq_status[name] = :down
        end
      end
    end
    notify "ALERT", alerts.join("\n") if alerts.any?
    update_services
  rescue => e
    Rails.logger.warn "[updown] Check status fail: #{e}"
    raise e if Rails.env.test?
  end

  def self.text_recap
    "Daemon: " + DAEMONS.values.uniq.map do |name|
      diff = (Time.now - @@last_checks[name].first) / 60 if @@last_checks[name].first
      if @@status[name] == :up
        "✔️ #{name.upcase} (#{diff&.round}m)"
      else
        "❌ #{name.upcase} (#{diff&.round}m)"
      end
    end.join(' ') + "\n" +
    "Sidekiq: " + WORKERS.values.uniq.map do |name|
      diff = (Time.now - @@last_sidekiq_ping[name].first) / 60 if @@last_sidekiq_ping[name].first
      if @@sidekiq_status[name] == :up
        "✔️ #{name.upcase} (#{diff&.round}m)"
      else
        "❌ #{name.upcase} (#{diff&.round}m)"
      end
    end.join(' ')
  end

  def self.check_postmark
    # https://status.postmarkapp.com/api
    response = Net::HTTP.get(URI("https://status.postmarkapp.com/api/v1/components"))
    components = JSON.parse(response).fetch('components')
    api_state = components.find {|s| s['name'].include?("API") }&.dig('state')
    smtp_state = components.find {|s| s['name'].include?("SMTP (sending)") }&.dig('state')
    # can be "operational", "degraded" or "under_maintenance"
    service = Service.find_by(permalink: 'email-notifications')
    target = if api_state == "degraded"
      3 # partial-outage (we can't send, may even be loosing some messages)
    elsif smtp_state == "degraded"
      2 # degraded-performance (no API problem but likely sending delays)
    elsif api_state == "under_maintenance" || smtp_state == "under_maintenance"
      5 # maintenance
    else
      1 # operational
    end
    Rails.logger.info "[updown] Postmark check: #{status}. Service status: #{service.status_id} → #{target}"
    if target != service.status_id and service.no_manual_status?
      service.update_attribute(:status_id, target)
    end
  rescue => e
    Rails.logger.warn "[updown] Postmark check fail: #{e}"
  end

  def self.check_web_url service, url, timeout: 10, ok_time: 500 # ms
    response = nil
    timing = Benchmark.ms do
      begin
        uri = URI(url)
        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https', open_timeout: timeout, read_timeout: timeout) { |http| http.head(uri).code.to_i }
      rescue => e
        response = e
      end
    end
    target = case response
      when 200 then (timing < ok_time ? 1 : 2) # operational or degraded-performance
      when 503 then 5 # maintenance
      else 4 # major-outage
    end
    Rails.logger.info "[updown] Web check (#{url}): #{response} (#{timing.round(1)} ms) Service status: #{service.status_id} → #{target}"
    if target != service.status_id and service.no_manual_status?
      service.update_attribute(:status_id, target)
    end
  end

  WEB_ENDPOINTS = [
    ["web", "https://updown.io/users/sign_in", 1000],
    ["api", "https://updown.io/api/checks/ngg8?api-key=ro-ilx4voqgu8l8bxqu0tld", 1000],
    ["custom-status-pages", "https://meta.updown.io", 2000],
  ].freeze

  def self.check_web_urls
    Service.find_by(permalink: 'email-notifications')
    WEB_ENDPOINTS.each do |srv, url, ok_time|
      service = Service.find_by(permalink: srv)
      check_web_url service, url, ok_time: ok_time
    end
  rescue => e
    Rails.logger.warn "[updown] Web check fail: #{e}"
  end

  def self.ping name
    @@last_checks[name].unshift Time.now
    @@last_checks[name] = @@last_checks[name][0, 20] if @@last_checks[name].size > 20
    if @@status[name] == :down
      @@status[name] = :up
      notify "RECOVERY", "#{name.upcase} is monitoring again"
    end
    if @@status['global'] == :down
      @@status['global'] = :up
      notify "RECOVERY", "updown is monitoring again"
    end
    update_services
  end

  def self.sidekiq name, params
    @@last_sidekiq_ping[name].unshift Time.now
    @@last_sidekiq_ping[name] = @@last_sidekiq_ping[name][0, 20] if @@last_sidekiq_ping[name].size > 20
    @@disabled_locations = params[:disabled_locations].reject(&:blank?) if params[:disabled_locations]
    healthy = (params[:queues] && params[:queues][:mailers].to_i < 10 && params[:queues][:default].to_i < 5000 && params[:queues][:low].to_i < 10000)
    if healthy && @@sidekiq_status[name] == :down
      @@sidekiq_status[name] = :up
      notify "RECOVERY", "#{name.upcase} sidekiq is working again: #{params[:queues].to_json}"
    elsif !healthy && @@sidekiq_status[name] == :up
      @@sidekiq_status[name] = :down
      notify "ALERT", "#{name.upcase} sidekiq queue too big: #{params[:queues].to_json}"
    end
    update_services
  end

  def self.update_services
    services = Service.all.group_by(&:permalink)
    DAEMONS.each do |ip, name|
      if service = services["daemon-#{name}"]&.first
        target = if @@disabled_locations.include?(name)
          5 # maintenance
        elsif @@status[name] == :down or @@status['global'] == :down
          4 # major-outage
        elsif @@sidekiq_status[name] == :down
          3 # partial-outage
        else
          1 # operational
        end
        if target != service.status_id and service.no_manual_status?
          Rails.logger.info "[updown] Updating service #{service.permalink}: #{service.status_id} → #{target}"
          service.update_attribute(:status_id, target)
        end
      end
    end
  end

  Updown.reset_storage!

  # Start background thread to send alerts
  Thread::abort_on_exception = true
  Thread.new do
    while true
      sleep REFRESH_RATE
      Updown.check_status
      Updown.check_postmark
      Updown.check_web_urls
    end
  end

  # Generate some fake data in dev
  if Rails.env.development?
    40.times do |i|
      @@last_checks[DAEMONS.values.sample] << Time.now - i * 30
      WORKERS.values.each do |s|
        @@last_sidekiq_ping[s] << Time.now - i * 60
      end
    end
  end
end