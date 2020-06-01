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

def start_hunter(btc)
  _profit = btc.regulate.resistance
  _loss   = btc.regulate.support
  _cost   = btc.regulate.cost
  _latest = btc.recent_price

  if _latest > _profit
    stop_profit(btc)
    btc.regulate.update(resistance: _latest)
    btc.regulate.update(support: _latest * 0.997)
  end

  if _latest < _loss
    all_out(btc)
  end

  if _latest < _cost
    amount = btc.regulate.fast_cash
    quota = btc.regulate.retain
    funds = btc.all_funds
    if funds < quota * 0.5
      amount = quota * 0.6 - funds
    end
    btc.step_price_bid(amount)
    btc.regulate.update(cost: _latest)
  end
end

def stop_profit(btc)
  amount = btc.regulate.fast_cash
  btc.market_price_ask(amount)
end

def all_out(btc)
  btc.sync_fund
  amount = btc.fund&.balance
  btc.market_price_ask(amount)
  btc.regulate.toggle(:fast_trade)
  btc.regulate.toggle(:range_trade)
end

while($running) do
  begin
    btc = Market.first
    if btc&.regulate&.fast_trade
      start_hunter(btc)
    end
  rescue => detail
    Notice.dingding("羊毛党 Robot：\n #{detail.message} \n #{detail.backtrace[0..5].join("\n")}")
  end
  sleep 30
end
