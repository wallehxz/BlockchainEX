class Backend::MarketsController < Backend::BaseController
  def index
    @markets = Market.seq.paginate(page:params[:page])
  end

  def new
  end

  def create
    @market = Market.new(market_params)
    if @market.save
      redirect_to backend_markets_path, notice: '新交易市场添加成功'
    else
      flash[:warn] = "请完善表单信息"
      render :new
    end
  end

  def edit
  end

  def update
    if @market.update(exchange_params)
      redirect_to backend_markets_path, notice: '交易市场更新成功'
    else
      flash[:warn] = "请完善表单信息"
      render :edit
    end
  end

  def destroy
    @market.destroy
    flash[:notice] = "交易市场删除成功"
    redirect_to :back
  end

  def sync_balance
    @market.sync_fund rescue nil
    @market.sync_cash rescue nil
    flash[:notice] = "账户资金数量同步成功"
    redirect_to :back
  end

  def clear_candles
    @market.candles.destroy_all
    flash[:notice] = "行情数据清空"
    redirect_to :back
  end

  def sync_candles
    @market.batch_quote(1000)
    flash[:notice] = "最新行情数据同步成功"
    redirect_to :back
  end

private

  def market_params
    params.require(:market).permit(:sequence, :quote_unit, :base_unit, :source)
  end

  def exchange_params
    Market.exchanges.each do |ex|
      return params.require(ex.to_sym).permit(:sequence, :quote_unit, :base_unit, :source) if params[ex.to_sym]
    end
  end
end
