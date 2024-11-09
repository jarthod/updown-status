class UpdownController < ApplicationController
  # Disable any action that require DB so that these action can work without it. They may still
  # fail at the end when Services are updated, but at least the important memory state would be ok.
  skip_before_action :verify_authenticity_token, :ensure_site, :set_browser_id
  skip_around_action :set_time_zone

  def ping
    Rails.logger.info "[updown] /ping received from #{remote_ip} (X-Forwarded-For: #{request.x_forwarded_for} → #{request.forwarded_for}, remote_ip: #{request.remote_ip}, ip: #{request.ip})"
    if Updown::DAEMONS.key? remote_ip
      name = Updown::DAEMONS[remote_ip]
      Updown.ping name
      head :ok
    else
      head :forbidden
    end
  end

  def sidekiq
    Rails.logger.info "[updown] /sidekiq received from #{remote_ip} (X-Forwarded-For: #{request.x_forwarded_for} → #{request.forwarded_for}, remote_ip: #{request.remote_ip}, ip: #{request.ip})"
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
    # if request.forwarded_for.present?
    #   # Find any IP in the X-forwarded-for matching
    #   request.forwarded_for.find { |ip| Updown::WORKERS[ip] }
    # else
      request.remote_ip
    # end
  end
end
