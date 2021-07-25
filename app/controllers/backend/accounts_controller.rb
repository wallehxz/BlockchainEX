class Backend::AccountsController < Backend::BaseController

  def index
    @accounts = Account.paginate(page:params[:page])
  end

  def sync_balance
    Market.all.each do |ex|
      ex.sync_balance rescue nil
    end
    flash[:notice] = "交易所所资金同步成功"
    redirect_to backend_accounts_path
  end

  def destroy
    @account.destroy
    flash[:notice] = "账户资金清空成功"
    redirect_to :back
  end
end
