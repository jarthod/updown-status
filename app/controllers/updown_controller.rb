class UpdownController < ApplicationController
  skip_before_action :verify_authenticity_token

  def ping
    if Updown::DAEMONS.key? request.remote_ip
      name = Updown::DAEMONS[request.remote_ip]
      Updown.ping name
      head :ok
    else
      head :forbidden
    end
  end

  def sidekiq
    if Updown::WORKERS.key? request.remote_ip
      return head :forbidden if params[:env] != 'production'
      name = Updown::WORKERS[request.remote_ip]
      Updown.sidekiq name, params
      head :ok
    else
      head :forbidden
    end
  end
end
