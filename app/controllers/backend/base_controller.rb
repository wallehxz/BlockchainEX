class Backend::BaseController < ApplicationController
  load_and_authorize_resource
  layout 'admin'

  def current_ability
    @current_ability ||= Ability.new(current_user)
  end
end
