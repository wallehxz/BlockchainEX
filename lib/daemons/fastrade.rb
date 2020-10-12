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
    coin.sync_fund
    balance = coin.fund.balance
    amount = coin.regulate.fast_cash
    if balance > 0.01
      coin.regulate.update(resistance: _latest * 1.0025, support: _latest * 0.9975)
      unless coin.regulate.takeprofit
        coin.regulate.toggle!('takeprofit')
        content = "#{coin.symbols} 开启止盈 #{Time.now.to_s(:short)}"
        Notice.dingding(content)
      end
    end
  end

  if _latest < _cost
    amount = coin.regulate.fast_cash
    quota = coin.regulate.retain
    coin.step_price_bid(amount)
    coin.regulate.update(cost: _latest * 0.998)
  end
end

while($running) do
  begin
    Regulate.where(fast_trade: true).each do |regul|
      start_hunter(regul.market)
    end
  rescue => detail
    Notice.dingding("FastTrade：\n #{detail.message} \n #{detail.backtrace[0..5].join("\n")}")
  end
  sleep 30
end
