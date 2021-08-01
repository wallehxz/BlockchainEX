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
  sleep 60
end
