class UpdownController < ApplicationController
  skip_before_action :verify_authenticity_token

  def ping
    Rails.logger.warn "[updown] /ping received from #{request.ip} (X-Forwarded-For: #{request.x_forwarded_for} → #{request.forwarded_for}, Fly-Client-IP: #{request.env['HTTP_FLY_CLIENT_IP']}, remote_ip: #{request.remote_ip})"
    if Updown::DAEMONS.key? request.ip
      name = Updown::DAEMONS[request.ip]
      Updown.ping name
      head :ok
    else
      head :forbidden
    end
  end

  def sidekiq
    Rails.logger.warn "[updown] /sidekiq received from #{request.ip} (X-Forwarded-For: #{request.x_forwarded_for} → #{request.forwarded_for}, Fly-Client-IP: #{request.env['HTTP_FLY_CLIENT_IP']}, remote_ip: #{request.remote_ip})"
    if Updown::WORKERS.key? request.ip
      return head :forbidden if params[:env] != 'production'
      name = Updown::WORKERS[request.ip]
      Updown.sidekiq name, params
      head :ok
    else
      head :forbidden
    end
  end
end
