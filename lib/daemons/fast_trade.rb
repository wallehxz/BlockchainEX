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

def start_hunter(coin)
  _profit = coin.regulate.resistance
  _cost   = coin.regulate.cost
  _latest = coin.recent_price

  if _latest > _profit
    amount = coin.regulate.fast_cash
    coin.step_price_ask(amount)
    coin.regulate.update(resistance: _latest)
    coin.regulate.update(support: _latest * 0.998)
  end

  if _latest < _cost
    amount = coin.regulate.fast_cash
    quota = coin.regulate.retain
    funds = coin.all_funds
    if funds < quota * 0.5
      amount = quota * 0.6 - funds
    end
    coin.step_price_bid(amount)
    coin.regulate.update(cost: _latest * 0.999)
  end
end

while($running) do
  begin
    Market.all.each do |coin|
      if coin&.regulate&.fast_trade
        start_hunter(coin)
      end
    end
  rescue => detail
    Notice.dingding("TradeBot：\n #{detail.message} \n #{detail.backtrace[0..5].join("\n")}")
  end
  sleep 30
end
