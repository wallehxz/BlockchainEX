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

def binance_trade(regul)
  market = regul.market
  profit = regul.cash_profit
  cost   = regul.cost
  price  = market.get_price[:bid]
  amount = regul.fast_cash

  market.sync_fund
  balance = market.fund.balance
  retain  = regul.retain
  if balance < retain * 0.01
    market.off_takeprofit
    content = "[#{Time.now.to_s(:short)}] #{market.symbols} 已经完成卖出计划，关闭止盈进程"
    Notice.dingding(content)
  end

  if price > cost + profit
    trends = market.get_ticker('1m', 1).kline_trends[0]
    if trends > 0
      market.step_price_ask(amount)
    else
      market.market_price_ask(amount * 0.5)
    end
  end
end

def future_trade(regul)
  profit = regul.support
  market = regul.market
  amount = regul.fast_cash
  long = market.long_position
  if long['unrealizedProfit'].to_f > profit
    price  = market.get_price
    trends = coin.get_ticker('1m', 15).map {|x| x[4].to_f}
    trends = coin.get_ticker('1m', 15).map {|x| x[4].to_f}
    if trends.max == trends[-2]
      market.new_ping_long(price[:bid], long['positionAmt'].to_f.abs, 'market')
    end
  end

  short = market.short_position
  if short['unrealizedProfit'].to_f > profit
    price  = market.get_price
    trends = coin.get_ticker('1m', 15).map {|x| x[4].to_f}
    if trends.min == trends[-2]
      market.new_ping_short(price[:bid], amount, 'market')
    end
  end
end


while($running) do
  begin
    Regulate.where(takeprofit: true).each do |regul|
      future_trade(regul)  if regul.market.source == 'future'
      binance_trade(regul) if regul.market.source == 'binance'
    end
  rescue => detail
    Notice.exception(detail, "Deamon TakeProfit")
  end
  sleep 29
end
