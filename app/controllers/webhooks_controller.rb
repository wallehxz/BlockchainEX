class WebhooksController < ApplicationController

  # url  http://gogogle.cc/trade
  # body = {"market": "YFI-USDT", "cmd": "step|market|bid|ask|cache|all_in", "msg": "text"}
  def trade
    trading    if params[:cmd] =~ /(bid)|(ask)/
    cache      if params[:cmd] =~ /cache/
    build      if params[:cmd] =~ /build/
    all_in     if params[:cmd] =~ /all_in/
    stoploss   if params[:cmd] =~ /stop/
    takeprofit if params[:cmd] =~ /take/
    chasedown  if params[:cmd] =~ /chase/
    boat       if params[:cmd] =~ /boat/
    signal     if params[:cmd] =~ /signal/
    diup       if params[:cmd] =~ /diup/
    render json: {msg: 'success!'}
  end

private

  def find_market
    m_id = Market.market_list[params[:market]]
    market = Market.find(m_id)
  end

  def trading
    market = find_market
    if market&.regulate
      amount = market.regulate.fast_cash
      profit = market.regulate.fast_profit || 0.002
      if params[:cmd] =~ /bid/
        bid_order(market, amount, profit)
      elsif params[:cmd] =~ /ask/
        ask_order(market, amount, profit)
      end
    end
  end

  def bid_order(market, amount, profit)
    price = market.recent_price * (1 - profit)
    if params[:cmd] =~ /(step)|(market)/
      market.send("#{$1 || $2}_price_bid".to_sym, amount)
    else
      market.new_bid(price, amount)
    end
  end

  def ask_order(market,amount, profit)
    price = market.recent_price * (1 + profit)
    if params[:cmd] =~ /(step)|(market)/
      market.send("#{$1 || $2}_price_ask".to_sym, amount)
    else
      aks_order = market.new_ask(price, amount)
    end
  end

  def cache
    coin = find_market
    coin.indicators.create(name: params[:msg])
    Indicator.where("created_at < ?", Time.now - 2.hour).destroy_all
  end

  def build
    market = find_market
    regul = market&.regulate
    market.on_chasedown
    amount = regul.retain * 0.2
    content = "[#{Time.now.to_s(:short)}] #{market.symbols} 开启建仓，持仓风控，市价买入 #{amount}"
    Notice.dingding(content)
    market.market_price_bid(amount)
  end

  def all_in
    market = find_market
    amount = market.regulate.retain
    market.market_price_bid(amount)
    content = "[#{Time.now.to_s(:short)}] #{market.symbols} 市价全仓买入#{amount}"
    Notice.dingding(content)
  end

  def stoploss
    market = find_market
    market.on_stoploss
    content = "[#{Time.now.to_s(:short)}] #{market.symbols} 开启止损 "
    Notice.dingding(content)
  end

  def takeprofit
    market = find_market
    market.step_takeprofit
  end

  def chasedown
    market = find_market
    market.on_chasedown
    content = "[#{Time.now.to_s(:short)}] #{market.symbols} 开启追跌交易 "
    Notice.dingding(content)
  end

  def boat
    market = find_market
    if market.greedy?
      market.on_chasedown
      content = "[#{Time.now.to_s(:short)}] #{market.symbols} 开启追跌交易 "
      Notice.dingding(content)
    end
  end

  def signal
    market = find_market
    indtor = market.indicators.macds.last
    if indtor.macd_s_up?
      market.step_chasedown("上涨金叉持仓买进")
    end
  end

  def diup
    market = find_market
    indtor = market.indicators.dmis.last
    if indtor.dmi_dd > indtor.dmi_di
      market.step_chasedown("DMI 指标上涨")
    end
  end

end
