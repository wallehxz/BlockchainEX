class WebhooksController < ApplicationController

  # url  http://gogogle.cc/trade
  # body = {"market": "YFI-USDT", "cmd": "step|market|bid|ask|cache|all_in", "msg": "text"}
  def trade
    trading    if params[:cmd] =~ /(bid)|(ask)/
    f_trade    if params[:cmd] =~ /(long)|(short)/
    cache      if params[:cmd] =~ /cache/
    build      if params[:cmd] =~ /build/
    all_in     if params[:cmd] =~ /all_in/
    stoploss   if params[:cmd] =~ /stop/
    takeprofit if params[:cmd] =~ /take/
    chasedown  if params[:cmd] =~ /chase/
    boat       if params[:cmd] =~ /boat/
    signal     if params[:cmd] =~ /signal/
    f_up       if params[:cmd] =~ /fup/
    f_down     if params[:cmd] =~ /fdown/
    m_up       if params[:cmd] =~ /mup/
    m_down     if params[:cmd] =~ /mdown/
    f_take     if params[:cmd] =~ /ftake/
    render json: {msg: 'success!'}
  end

private

  def find_market
    m_id = Market.market_list[params[:market]]
    market = Market.find(m_id)
  end

  def f_take
    market = find_market
    price  = market.get_price[:ask]
    long   = market.long_position
    if long['positionAmt'].to_f.abs > 0
      market.new_ping_long(price, long['positionAmt'].to_f.abs, 'market')
    end
    short  = market.short_position
    if short['positionAmt'].to_f.abs > 0
      market.new_ping_short(price, short['positionAmt'].to_f.abs, 'market')
    end
  end

  def m_up
    market = find_market
    price  = market.get_price[:ask]
    long   = market.long_position
    amount = market.regulate.retain
    if long['positionAmt'].to_f.abs > 0
      market.new_ping_long(price, long['positionAmt'].to_f.abs, 'market')
    end
    market.new_kai_short(price, amount, 'market')
  end

  def m_down
    market = find_market
    price  = market.get_price[:ask]
    short  = market.short_position
    amount = market.regulate.retain
    if short['positionAmt'].to_f.abs > 0
      market.new_ping_short(price, short['positionAmt'].to_f.abs, 'market')
    end
    market.new_kai_long(price, amount, 'market')
  end

  #行情指标最高价，平多 开空
  def f_up
    market = find_market
    price  = market.get_price[:bid]
    amount = market.regulate.fast_cash
    long   = market.long_position
    if long['unrealizedProfit'].to_f > 0
      market.new_ping_long(price, long['positionAmt'].to_f.abs, 'market')
    end
    if market.cma_down?
      market.new_kai_short(price, amount, 'market')
    end
  end

  #行情指标最低价，平空 开多
  def f_down
    market = find_market
    price  = market.get_price[:bid]
    amount = market.regulate.fast_cash
    short  = market.short_position
    if short['unrealizedProfit'].to_f > 0
      market.new_ping_short(price, short['positionAmt'].to_f.abs, 'market')
    end
    if market.cma_up?
      market.new_kai_long(price, amount, 'market')
    end
  end

  def f_trade
    market = find_market
    if market&.regulate
      if params[:cmd] =~ /short/
        if params[:cmd] =~ /kai/
          short_kai_order(market)
        end

        if params[:cmd] =~ /ping/
          short_ping_order(market)
        end
      end

      if params[:cmd] =~ /long/
        if params[:cmd] =~ /kai/
          long_kai_order(market)
        end

        if params[:cmd] =~ /ping/
          long_ping_order(market)
        end
      end

    end
  end

  def short_kai_order(market)
    amount = market.regulate.fast_cash
    price  = market.get_price
    if params[:cmd] =~ /market/
      market.new_kai_short(price[:bid], amount, 'market')
    else
      market.new_kai_short(price[:ask], amount)
    end
  end

  def short_ping_order(market)
    amount = market.regulate.fast_cash
    price  = market.get_price
    if params[:cmd] =~ /market/
      market.new_ping_short(price[:ask], amount, 'market')
    else
      market.new_ping_short(price[:bid], amount)
    end
  end

  def long_kai_order(market)
    amount = market.regulate.fast_cash
    price  = market.get_price
    if params[:cmd] =~ /market/
      market.new_kai_long(price[:ask], amount, 'market')
    else
      market.new_kai_long(price[:bid], amount)
    end
  end

  def long_ping_order(market)
    amount = market.regulate.fast_cash
    price  = market.get_price
    if params[:cmd] =~ /market/
      market.new_ping_long(price[:bid], amount, 'market')
    else
      market.new_ping_long(price[:ask], amount)
    end
  end

  def trading
    market = find_market
    if market&.regulate
      amount = market.regulate.fast_cash
      if params[:cmd] =~ /bid/
        bid_order(market, amount)
      elsif params[:cmd] =~ /ask/
        ask_order(market, amount)
      end
    end
  end

  def bid_order(market, amount)
    price = market.recent_price
    if params[:cmd] =~ /(step)|(market)/
      market.send("#{$1 || $2}_price_bid".to_sym, amount)
    else
      market.new_bid(price, amount)
    end
  end

  def ask_order(market,amount)
    price = market.recent_price
    if params[:cmd] =~ /(step)|(market)/
      market.send("#{$1 || $2}_price_ask".to_sym, amount)
    else
      aks_order = market.new_ask(price, amount)
    end
  end

  def cache
    coin = find_market
    coin.indicators.create(name: params[:msg])
    Indicator.where("created_at < ?", Time.now - 12.hour).destroy_all
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
