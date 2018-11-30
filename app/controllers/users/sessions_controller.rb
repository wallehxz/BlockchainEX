class Users::SessionsController < Devise::SessionsController
  layout 'user'
# before_filter :configure_sign_in_params, only: [:create]

  # GET /resource/sign_in
  # def new
  #   super
  # end

  # POST /resource/sign_in
  def create
    super
    cookies.signed[:user_id] = current_user.id if params[:user][:remember_me] == '1'
  end

  # DELETE /resource/sign_out
  def destroy
    cookies.delete :user_id if cookies.signed[:user_id]
    super
  end

  # protected

  # You can put the params you want to permit in the empty array.
  # def configure_sign_in_params
  #   devise_parameter_sanitizer.for(:sign_in) << :attribute
  # end
end
