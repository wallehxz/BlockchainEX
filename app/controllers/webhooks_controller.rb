class WebhooksController < ApplicationController

  # url  http://gogogle.cc/trade
  # body = {"market": "BTC-USDT", "cmd": "step|market|bid", "msg": "text"}
  def trade
    trading    if params[:cmd] =~ /(bid)|(ask)/
    cache      if params[:cmd] =~ /cache/
    build      if params[:cmd] =~ /build/
    all_in     if params[:cmd] =~ /all_in/
    stoploss   if params[:cmd] =~ /stop/
    takeprofit if params[:cmd] =~ /take/
    chasedown  if params[:cmd] =~ /chase/
    boat       if params[:cmd] =~ /boat/
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
  end

  def build
    market = find_market
    regul = market&.regulate
    regul.toggle!(:fast_trade) unless regul.fast_trade
    regul.toggle!(:chasedown)  unless regul.chasedown
    if market.regulate.chasedown
      content = "[#{Time.now.to_s(:short)}] #{market.symbols} 开启高频交易,开启追跌交易 "
      Notice.dingding(content)
      amount = regul.retain / 4.0
      market.step_price_bid(amount)
    end
  end

  def all_in
    market = find_market
    amount = market.regulate.retain
    market.market_price_bid(amount)
    content = "[#{Time.now.to_s(:short)}] #{market.symbols} 市价满仓入场 数量#{amount}"
    Notice.dingding(content)
  end

  def stoploss
    market = find_market
    regul = market.regulate
    unless regul.stoploss
      regul.toggle!(:stoploss)
      content = "[#{Time.now.to_s(:short)}] #{market.symbols} 开启止损 "
      Notice.dingding(content)
    end
    Daemon.start('stoploss')
  end

  def takeprofit
    market = find_market
    regul = market.regulate
    unless regul.takeprofit
      cur_price = market.recent_price
      regul.toggle!(:takeprofit)
      regul.update(support: cur_price, resistance: cur_price * 1.005)
      content = "[#{Time.now.to_s(:short)}] #{market.symbols} 开启止盈  止损价更新为 #{cur_price}"
      Notice.dingding(content)
    end
    Daemon.start('takeprofit')
  end

  def chasedown
    market = find_market
    regul  = market&.regulate
    unless regul.chasedown
      regul.toggle!(:chasedown)
      content = "[#{Time.now.to_s(:short)}] #{market.symbols} 开启追跌交易 "
      Notice.dingding(content)
    end
  end

  def boat
    market = find_market
    regul  = market&.regulate
    if market.greedy?
      unless regul.chasedown
        regul.toggle!(:chasedown)
        content = "[#{Time.now.to_s(:short)}] #{market.symbols} 开启追跌交易 "
        Notice.dingding(content)
      end
    end
  end

end

# #!/usr/bin/env ruby

# # You might want to change this
# ENV["RAILS_ENV"] ||= "production"

# root = File.expand_path(File.dirname(__FILE__))
# root = File.dirname(root) until File.exists?(File.join(root, 'config'))
# Dir.chdir(root)

# require File.join(root, "config", "environment")

# $running = true

# Signal.trap("TERM") do
#   $running = false
# end

# # tradingview 通知格式 #BTC_USDT|RSI1 <=> 70|market|ask
# # subject= "#BTC_USDT|RSI1 <=> 70|step|bid"
# def start_trade(subject)
#   trading = subject.split('|')
#   quote = trading[0].split('_')
#   market = Market.find_by_quote_unit_and_base_unit(quote[0],quote[1])
#   if market&.regulate
#     amount = market.regulate.fast_cash
#     profit = market.regulate.fast_profit || 0.002
#     side = trading[-1]
#     if side == 'bid'
#       bid_order(market, amount, profit, subject)
#     elsif side == 'ask'
#       ask_order(market, amount, profit, subject)
#     end
#   end
# end

# def bid_order(market, amount, profit, subject)
#   _latest = market.recent_price
#   price = _latest * (1 - profit)
#   market.regulate.update(cost: _latest * 0.998)
#   content = ''
#   if subject =~ /(step)|(market)/
#     content = "[#{Time.now.to_s(:short)}] #{market.full_name} bid #{$1} amount: #{amount}"
#     market.send("#{$1 || $2}_price_bid".to_sym, amount)
#   else
#     content = "[#{Time.now.to_s(:short)}] #{market.full_name} bid limit amount: #{amount}"
#     market.new_bid(price, amount)
#   end
#   Notice.dingding(content)
# end

# def ask_order(market,amount, profit, subject)
#   price = market.recent_price * (1 + profit)
#   content = ''
#   if subject =~ /(step)|(market)/
#     content = "[#{Time.now.to_s(:short)}] #{market.full_name} ask #{$1} amount: #{amount}"
#     market.send("#{$1 || $2}_price_ask".to_sym, amount)
#   else
#     content = "[#{Time.now.to_s(:short)}] #{market.full_name} ask limit amount: #{amount}"
#     aks_order = market.new_ask(price, amount)
#   end
#   Notice.dingding(content)
# end

# def stoploss(subject)
#   trading = subject.split('|')
#   quote = trading[0].split('_')
#   market = Market.find_by_quote_unit_and_base_unit(quote[0],quote[1])
#   regul = market.regulate
#   unless regul.stoploss
#     regul.toggle!(:stoploss)
#     content = "[#{Time.now.to_s(:short)}] #{market.symbols} 开启止损 "
#     Notice.dingding(content)
#   end

#   Daemon.start('stoploss')
# end

# def takeprofit(subject)
#   trading = subject.split('|')
#   quote = trading[0].split('_')
#   market = Market.find_by_quote_unit_and_base_unit(quote[0],quote[1])
#   regul = market.regulate
#   unless regul.takeprofit
#     cur_price = market.recent_price
#     regul.toggle!(:takeprofit)
#     regul.update(support: cur_price, resistance: cur_price * 1.005)
#     content = "[#{Time.now.to_s(:short)}] #{market.symbols} 开启止盈  止损价更新为 #{cur_price}"
#     Notice.dingding(content)
#   end
#   Daemon.start('takeprofit')
# end

# def build(subject)
#   trading = subject.split('|')
#   quote   = trading[0].split('_')
#   market  = Market.find_by_quote_unit_and_base_unit(quote[0],quote[1])
#   regul   = market&.regulate
#   regul.toggle!(:fast_trade) unless regul.fast_trade
#   regul.toggle!(:chasedown)  unless regul.chasedown
#   content = "[#{Time.now.to_s(:short)}] #{market.symbols} 开启高频交易,开启追跌交易 "
#   Notice.dingding(content)
#   amount = regul.retain / 4.0
#   market.step_price_bid(amount)
# end

# def all_in(subject)
#   trading = subject.split('|')
#   quote = trading[0].split('_')
#   market = Market.find_by_quote_unit_and_base_unit(quote[0],quote[1])
#   if market&.regulate&.fast_trade
#     amount = market.regulate.retain
#     market.market_price_bid(amount)
#   end
# end

# def macd(subject)
#   if subject.match(/macd-?\d+/)
#     subject.match(/macd-?\d+/)[0].match(/-?\d+/)[0].to_i
#   end
# end

# def chasedown(subject)
#   trading = subject.split('|')
#   quote   = trading[0].split('_')
#   market  = Market.find_by_quote_unit_and_base_unit(quote[0],quote[1])
#   regul   = market&.regulate
#   unless regul.chasedown
#     regul.toggle!(:chasedown)
#     content = "[#{Time.now.to_s(:short)}] #{market.symbols} 开启追跌交易 "
#     Notice.dingding(content)
#   end
# end

# def cache(subject)
#   trading = subject.split('|')
#   quote   = trading[0].split('_')
#   market  = Market.find_by_quote_unit_and_base_unit(quote[0],quote[1])
#   market.indicators.create(name: trading[1])
# end

# def boat(subject)
#   trading = subject.split('|')
#   quote   = trading[0].split('_')
#   market  = Market.find_by_quote_unit_and_base_unit(quote[0],quote[1])
#   regul   = market&.regulate
#   if market.greedy?
#     unless regul.chasedown
#       regul.toggle!(:chasedown)
#       content = "[#{Time.now.to_s(:short)}] #{market.symbols} 开启追跌交易 "
#       Notice.dingding(content)
#     end
#   end
# end

# while($running) do
#   begin
#     mails = Mail.all.select { |x| x.from[0] =~ /tradingview/ } rescue []
#     mails.each do |email|
#       if email.subject.include? '#'
#         subject = email.subject
#         topic = subject.delete(' ').split('#')[-1]
#         start_trade(topic) if topic =~ /(bid)|(ask)/
#         cache(topic)      if topic =~ /cache/
#         build(topic)      if topic =~ /build/
#         all_in(topic)     if topic =~ /all_in/
#         stoploss(topic)   if topic =~ /stop/
#         takeprofit(topic) if topic =~ /take/
#         chasedown(topic)  if topic =~ /chase/
#         boat(topic)       if topic =~ /boat/
#       end
#     end
#   rescue => detail
#     Notice.dingding("TradingView：\n #{detail.message} \n #{detail.backtrace[0..5].join("\n")}")
#   end
#   sleep 10
# end


