class Backend::AccountsController < Backend::BaseController

  def index
    @accounts = Account.paginate(page:params[:page])
  end

  def destroy
    @account.destroy
    flash[:notice] = "账户资金清空成功"
    redirect_to :back
  end
end
