class UpdownController < ApplicationController
  skip_before_action :verify_authenticity_token

  def ping
    if Updown::DAEMONS.key? request.ip
      name = Updown::DAEMONS[request.ip]
      Updown.ping name
      head :ok
    else
      head :forbidden
    end
  end

  def sidekiq
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
