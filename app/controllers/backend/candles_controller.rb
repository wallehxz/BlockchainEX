class Backend::CandlesController < Backend::BaseController
  before_action :find_market

  def index
    @candles = @market.candles.recent.paginate(page:params[:page])
  end

  def destroy
    @candle.destroy
    flash[:notice] = "历史行情删除成功"
    redirect_to :back
  end

private

  def find_market
    @market = Market.find(params[:market_id])
  end

end
