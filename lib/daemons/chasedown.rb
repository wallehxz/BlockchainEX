#!/usr/bin/env ruby

# You might want to change this
ENV["RAILS_ENV"] ||= "production"

root = File.expand_path(File.dirname(__FILE__))
root = File.dirname(root) until File.exists?(File.join(root, 'config'))
Dir.chdir(root)

require File.join(root, "config", "environment")

$running = true
Signal.trap("TERM") do
  $running = false
end

# TODO
# 判断当前是否有之前的订单，如果没有，则拉取最新的行情，如果K线是下跌，且开始回弹，则追加订单

def chase_order(coin)
  trends = coin.get_ticker('1m', 2).kline_trends
  amount = coin.regulate.fast_cash

  if trends.max < 0
    coin.market_price_bid(amount * 0.5)
    coin.step_price_bid(amount)
  end
  if trends[0] < 0 && trends[1] > 0
    coin.market_price_bid(amount * 0.25)
  end
end

def all_to_off(coin)
  coin.sync_fund
  balance = coin.fund.balance
  _regul  = coin.regulate
  retain  = _regul.retain
  if balance > retain * 0.9
    _regul.update_avg_cost
    coin.off_chasedown
    content = "[#{Time.now.to_s(:short)}] #{coin.symbols} 已经买入足够数量 关闭追跌"
    Notice.dingding(content)
  end
end

def binance_trade(market)
  chase_order(market)
  all_to_off(market)
end

def future_trade(regul)
  market = regul.market
  amount = regul.fast_cash
  price = market.get_price[:bid]
  k = market.get_ticker('1m', 25).kline_c

  #价格下跌
  if k.min == k[-4..-2].min
    market.new_kai_long(price, amount, 'market')
  end

  if k.ma(5) > k.ma(10)
    market.new_kai_long(price, amount, 'market')
  end

  if k.max == k[-3..-2].max
    market.new_kai_short(price, amount, 'market')
  end

  #MA5 下穿 MA 10 此时价格为行情最大
  if k.ma(5) < k.ma(10) && k[-6..-2] > k.ma(10)
    market.new_kai_short(price, amount, 'market')
  end
end

while($running) do
  begin
    Regulate.where(chasedown: true).each do |regul|
      market = regul.market
      future_trade(regul)   if market.source == 'future'
      binance_trade(market) if market.source == 'binance'
    end
  rescue => detail
    Notice.exception(detail, "Deamon Chasedown")
  end
  sleep 60
end
