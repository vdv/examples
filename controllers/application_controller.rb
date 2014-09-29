class ApplicationController < ActionController::Base

  protect_from_forgery

  delegate :instrument, to: ActiveSupport::Notifications

end
