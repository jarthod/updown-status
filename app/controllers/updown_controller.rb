class UpdownController < ApplicationController
  skip_before_action :verify_authenticity_token

  def ping
    Rails.logger.info "[updown] /ping received from #{remote_ip} (X-Forwarded-For: #{request.x_forwarded_for} → #{request.forwarded_for}, Fly-Client-IP: #{request.env['HTTP_FLY_CLIENT_IP']}, remote_ip: #{request.remote_ip}, ip: #{request.ip})"
    if Updown::DAEMONS.key? remote_ip
      name = Updown::DAEMONS[remote_ip]
      Updown.ping name
      head :ok
    else
      head :forbidden
    end
  end

  def sidekiq
    Rails.logger.info "[updown] /sidekiq received from #{remote_ip} (X-Forwarded-For: #{request.x_forwarded_for} → #{request.forwarded_for}, Fly-Client-IP: #{request.env['HTTP_FLY_CLIENT_IP']}, remote_ip: #{request.remote_ip}, ip: #{request.ip})"
    if Updown::WORKERS.key? remote_ip
      return head :forbidden if params[:env] != 'production'
      name = Updown::WORKERS[remote_ip]
      Updown.sidekiq name, params
      head :ok
    else
      head :forbidden
    end
  end

  def remote_ip
    # Fly.io fucks up the IP chain with proxies so we need to use their custom header.
    request.env['HTTP_FLY_CLIENT_IP'].presence || request.ip
  end
end
