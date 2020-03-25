class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  # before_action :cookie_user_auth
  protect_from_forgery with: :null_session

  rescue_from CanCan::AccessDenied do |exception|
    if current_user
      respond_to do |format|
        format.html { redirect_to root_path }
      end
    else
      respond_to do |format|
        format.html { redirect_to sign_in_path }
      end
    end
  end

  rescue_from StandardError do |exception|
    NoticeServices.exception(exception, 'Front-API', current_user)
    render json: { message: "服务器发生错误" }, status: :server_error
  end if Rails.env.production?

  rescue_from ActiveRecord::RecordNotFound do |exception|
    render json: { message: "数据不存在或已被删除" }, status: :not_found
  end

  def cookie_sign_in
    if current_user.nil? && cookies[:user_id]
      user = User.find cookies.signed[:user_id]
      sign_in(user)
    end
  end

  def authenticate_user!
    unless current_user
      redirect_to sign_in_path
    end
  end
end
