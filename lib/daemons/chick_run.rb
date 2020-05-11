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
  _latest = btc.recent_price

  if _latest > _profit
    stop_profit(btc)
  end

  if _latest < _loss
    stop_loss(btc)
  end

  if _latest < (btc.avg_cost - btc.regulate.fast_cash)
    stop_loss(btc)
  end
end

def stop_profit(btc)
  amount = btc.regulate.fast_cash
  btc.step_price_ask(amount)
end

def stop_loss(btc)
  btc.sync_fund
  amount = btc.fund&.balance
  btc.step_price_ask(amount)
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
