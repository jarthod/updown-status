=begin
class Rack::Attack
  # safelist_ip("5.6.7.0/24")
  # blocklist_ip("1.2.0.0/16")

  # Block annoying scanners
  blocklist("block scanners") do |req|
    # Detectify is sending shit in Accept header causing Mime::Type::InvalidMimeType
    req.user_agent&.match? /Detectify|Nuclei|Fuzz Faster/ or
    req.content_type&.match? /addHeader|passwd|symphony|\.\.\/|apache/ or
    req.get_header("HTTP_ACCEPT")&.match? /addHeader|passwd|symphony|\.\.\/|apache/
  end

  # AS35048 Biterika Group LLC
  # https://www.ip2location.com/as35048
  BITERIKA_IPS = %w(2.59.50.0/24 5.183.130.0/24 31.40.203.0/24 45.11.20.0/23 45.15.72.0/23 45.15.236.0/23 45.81.136.0/23 45.84.176.0/23 45.86.0.0/23 45.87.252.0/23 45.89.16.0/22 45.90.196.0/24 45.134.180.0/22 45.134.252.0/23 45.135.32.0/23 45.139.125.0/24 45.139.176.0/23 45.140.52.0/22 45.142.252.0/23 45.144.36.0/24 45.145.116.0/22 45.147.192.0/23 45.151.145.0/24 46.8.10.0/23 46.8.14.0/23 46.8.16.0/23 46.8.22.0/23 46.8.56.0/23 46.8.106.0/23 46.8.110.0/23 46.8.154.0/23 46.8.156.0/23 46.8.188.0/24 46.8.192.0/23 46.8.212.0/23 46.8.222.0/23 77.83.84.0/24 77.83.148.0/23 77.94.1.0/24 84.54.53.0/24 91.188.244.0/24 92.119.193.0/24 94.158.190.0/24 95.182.124.0/22 109.248.12.0/22 109.248.48.0/23 109.248.54.0/23 109.248.128.0/23 109.248.138.0/23 109.248.142.0/23 109.248.166.0/23 109.248.204.0/23 176.53.186.0/24 185.181.244.0/22 188.130.128.0/23 188.130.136.0/23 188.130.142.0/23 188.130.184.0/22 188.130.188.0/23 188.130.210.0/23 188.130.218.0/23 188.130.220.0/23 192.144.31.0/24 193.53.168.0/24 193.58.168.0/23 194.32.229.0/24 194.32.237.0/24 194.34.248.0/24 194.35.113.0/24 194.156.92.0/24 194.156.96.0/23 194.156.123.0/24 212.115.49.0/24 213.226.101.0/24 2a06:d647::/32 2a07:ca07::/32 2a0a:5680::/29 2a0a:b387::/32 2a0b:2d87::/32 2a0e:8140::/29 2a0e:cd40::/29 2a0f:d000::/29 2a11:4ac0::/43 2a11:4ac0:20::/44 2a11:4ac0:40::/42 2a11:4ac0:80::/41 2a11:4ac0:100::/40 2a11:4ac0:200::/39 2a11:4ac0:400::/38 2a11:4ac0:800::/37 2a11:4ac0:1000::/36 2a11:4ac0:2000::/35 2a11:4ac0:4000::/34 2a11:4ac0:8000::/33 2a11:4ac1::/32 2a11:4ac2::/31 2a11:4ac4::/30).map { |proxy| IPAddr.new(proxy) }
  blocklist("Biterika Group") do |req|
    remote_ip = req.get_header("action_dispatch.remote_ip").to_s
    if remote_ip.present?
      ipaddr = IPAddr.new(remote_ip)
      BITERIKA_IPS.any? { |ips| ips.include?(ipaddr) }
    end
  end

  # Throttle all requests by IP [ 1 req/sec ]
  # Key: "rack::attack:#{Time.now.to_i/60}:req/ip:#{req.remote_ip}"
  throttle("req/ip", limit: 60, period: 1.minute) do |req|
    req.get_header("action_dispatch.remote_ip").to_s
  end

  # Throttle requests with dangerous side effects [ 1 req/min ]
  # Key: "rack::attack:#{Time.now.to_i/600}:danger/ip:#{req.remote_ip}"
  throttle("danger/ip", limit: 10, period: 10.minute) do |req|
    case req.path
    when "/subscribe"
      # by remote IP or globally
      # req.get_header("action_dispatch.remote_ip") if req.patch? or req.post?
      "global" if req.patch? or req.post?
    end
  end
end

# Instrument events
ActiveSupport::Notifications.subscribe(/rack_attack/) do |name, start, finish, request_id, payload|
  Rails.logger.warn "Blocked by RackAttack: #{payload[:request].env['rack.attack.match_data']} #{payload[:request].env["rack.attack.throttle_data"]}"
end
=end