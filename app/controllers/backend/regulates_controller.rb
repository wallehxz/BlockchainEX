class Backend::RegulatesController < Backend::BaseController

  def index
    @regulates = Regulate.order('market_id').paginate(page:params[:page])
  end

  def new
  end

  def create
    @regulate = Regulate.new(regulate_params)
    if @regulate.save
      redirect_to backend_regulates_path, notice: '添加行情监管'
    else
      flash[:warn] = "请完善表单信息"
      render :new
    end
  end

  def edit
  end

  def update
    if @regulate.update(regulate_params)
      redirect_to backend_regulates_path, notice: '更新行情监管'
    else
      flash[:warn] = "请完善表单信息"
      render :edit
    end
  end

  def destroy
    @regulate.destroy
    flash[:notice] = "删除行情监管"
    redirect_to :back
  end

  def change_state
    if params[:kind] == 'sms'
      @regulate.toggle!(:notify_sms)
    elsif params[:kind] == 'wx'
      @regulate.toggle!(:notify_wx)
    elsif params[:kind] == 'dd'
      @regulate.toggle!(:notify_dd)
    elsif params[:kind] == 'fast'
      @regulate.toggle!(:fast_trade)
    elsif params[:kind] == 'range'
      @regulate.toggle!(:range_trade)
    elsif params[:kind] == 'stoploss'
      @regulate.toggle!(:stoploss)
    elsif params[:kind] == 'takeprofit'
      @regulate.toggle!(:takeprofit)
    elsif params[:kind] == 'chasedown'
      @regulate.toggle!(:chasedown)
    end
    render json: { message: 'Success'}
  end

  def kai_long
    amount = @regulate.fast_cash
    market = @regulate.market
    price  = market.get_book[:bid]
    market.new_kai_long(price, amount)
    flash[:notice] = "新增开多持仓"
    redirect_to :back
  end

  def ping_long
    market = @regulate.market
    price  = market.get_book[:ask]
    long   = market.long_position
    if long['positionAmt'].to_f.abs > 0
      market.new_ping_long(price, long['positionAmt'].to_f.abs)
      flash[:notice] = "开多持仓已完成平仓"
    end
    redirect_to :back
  end

  def kai_short
    amount = @regulate.fast_cash
    market = @regulate.market
    price  = market.get_book[:bid]
    market.new_kai_short(price, amount)
    flash[:notice] = "新增开空持仓"
    redirect_to :back
  end

  def ping_short
    market = @regulate.market
    price  = market.get_book[:ask]
    short  = market.short_position
    if short['positionAmt'].to_f.abs > 0
      market.new_ping_short(price, short['positionAmt'].to_f.abs)
      flash[:notice] = "开空持仓已完成平仓"
    end
    redirect_to :back
  end

private

  def regulate_params
    params.require(:regulate).permit(:market_id, :amount_precision, :price_precision,
     :retain, :support, :resistance, :cost, :cash_profit, :fast_profit, :fast_cash, :range_profit, :range_cash)
  end

end
