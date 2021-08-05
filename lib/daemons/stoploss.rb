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
  coin    = regul.market
  coin.sync_fund
  balance = coin.fund.balance

  if balance < regul.retain * 0.01
    coin.market_price_ask(balance)
    coin.off_stoploss
    content = "#{regul.market.symbols} 关闭止损 #{Time.now.to_s(:short)}"
    Notice.dingding(content)
  end

  if coin.get_price[:bid] > regul.cost
    amount = regul.fast_cash
    coin.step_price_ask(amount)
  end

  if coin.get_price[:bid] < regul.cost
    amount = regul.fast_cash
    coin.market_price_ask(amount)
  end
end

def future_trade(regul)
  market = regul.market
  price  = market.get_price[:ask]
  if market.cma_fast < 0
    long = market.long_position
    if long['positionAmt'].to_f.abs > 0 && long['unrealizedProfit'].to_f < 0
      market.new_ping_long(price, long['positionAmt'].to_f.abs, 'market')
    end
  end

  if market.cma_fast > 0
    short = market.short_position
    if short['positionAmt'].to_f.abs > 0 && short['unrealizedProfit'].to_f < 0
      market.new_ping_short(price, short['positionAmt'].to_f.abs, 'market')
    end
  end
end

while($running) do
  begin
    Regulate.where(stoploss: true).each do |regul|
      future_trade(regul)  if regul.market.source == 'future'
      binance_trade(regul) if regul.market.source == 'binance'
    end
  rescue => detail
    Notice.exception(detail, "Deamon StopLoss")
  end
  sleep 59
end
