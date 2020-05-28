require 'net/http'
require 'json'

module Updown
  DAEMONS = {
    '45.32.74.41' => 'lan',
    '104.238.136.194' => 'mia',
    '198.27.83.55' => 'bhs',
    '91.121.222.175' => 'rbx',
    '104.238.159.87' => 'fra',
    '45.32.107.181' => 'sin',
    '45.76.104.117' => 'tok',
    '45.63.29.207' => 'syd',
  }

  WEB = {
    '178.63.21.176' => 'db3',
    '91.121.222.175' => 'rbx',
  }

  WORKERS = WEB.merge(DAEMONS)
  REFRESH_RATE = 60 # sec

  mattr_accessor :last_checks, :status, :sidekiq_status, :last_sidekiq_ping

  def self.notify title, body
    return if Rails.env.development?
    Mail.deliver do
      from    "monitor@updown.io"
      to      "bigbourin@gmail.com"
      subject "[updown status] #{title}"
      body    "#{body} – https://status.updown.io"
      content_type "text/plain; charset=UTF-8"
    end
  end

  def self.reset_storage!
    @@last_checks = Hash.new { |h, k| h[k] = [Time.now] }
    @@last_sidekiq_ping = Hash.new { |h, k| h[k] = [Time.now] }
    @@status = Hash.new { |h, k| h[k] = :up }
    @@sidekiq_status = Hash.new { |h, k| h[k] = :up }
  end

  def self.check_status
    last_diff = Float::INFINITY
    DAEMONS.each do |ip, name|
      if @@last_checks[name].first
        diff = Time.now - @@last_checks[name].first
        last_diff = diff if diff < last_diff
        if diff > 3600 and @@status[name] == :up
          notify "ALERT on #{name}", "#{name} has stopped monitoring 1h ago"
          @@status[name] = :down
        end
      end
    end
    WORKERS.each do |ip, name|
      if @@last_sidekiq_ping[name].first
        diff = Time.now - @@last_sidekiq_ping[name].first
        if diff > 300 and @@sidekiq_status[name] == :up
          notify "SIDEKIQ ALERT on #{name}", "#{name} sidekiq stopped working 5m ago"
          @@sidekiq_status[name] = :down
        end
      end
    end
    if last_diff > 300 and @@status['global'] == :up
      notify "ALERT global", "No request received for 5m"
      @@status['global'] = :down
    end
    update_services
  rescue => e
    Rails.logger.warn "[updown] Check status fail: #{e}"
  end

  def self.check_postmark
    response = Net::HTTP.get(URI("https://status.postmarkapp.com/api/1.0/services"))
    status = JSON.parse(response).find {|s| s['name'].include?("API") }&.dig('status')
    service = Service.find_by(permalink: 'email-notifications')
    target = case status
      when "DELAY" then 2 # degraded-performance
      when "DEGRADED" then 3 # partial-outage
      when "DOWN" then 4 # major-outage
      when "MAINTENANCE" then 5 # maintenance
      when "UP" then 1 # operational
      else 1
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
        response = HTTP.timeout(timeout).head(url).code
      rescue HTTP::Error => e
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
      notify "RECOVERY on #{name}", "#{name} is monitoring again"
    end
    if @@status['global'] == :down
      @@status['global'] = :up
      notify "RECOVERY global", "updown is monitoring again"
    end
    update_services
  end

  def self.sidekiq name, params
    @@last_sidekiq_ping[name].unshift Time.now
    @@last_sidekiq_ping[name] = @@last_sidekiq_ping[name][0, 20] if @@last_sidekiq_ping[name].size > 20
    healthy = (params[:queues] && params[:queues][:mailers].to_i < 10 && params[:queues][:default].to_i < 5000 && params[:queues][:low].to_i < 10000)
    if healthy && @@sidekiq_status[name] == :down
      @@sidekiq_status[name] = :up
      notify "SIDEKIQ RECOVERY on #{name}", "#{name} sidekiq is working again"
    elsif !healthy && @@sidekiq_status[name] == :up
      @@sidekiq_status[name] = :down
      notify "SIDEKIQ ALERT on #{name}", "#{name} sidekiq queue too big: #{params[:queues].to_json}"
    end
    update_services
  end

  def self.update_services
    services = Service.all.group_by(&:permalink)
    DAEMONS.each do |ip, name|
      if service = services["daemon-#{name}"]&.first
        target = if @@status[name] == :down or @@status['global'] == :down
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