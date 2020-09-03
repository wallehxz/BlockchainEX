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

while($running) do
  begin
    Regulate.where(stoploss: true).each do |regul|
      coin    = regul.market
      _latest = coin.recent_price
      _average = coin.avg_cost rescue 0
      if _latest < _average
        regul.toggle!(:fast_trade) if regul.fast_trade
        amount = regul.retain / 10
        coin.sync_fund
        balance = coin.fund.balance
        if balance > amount
          coin.market_price_ask(amount)
        else
          coin.market_price_ask(balance * 0.99)
          regul.toggle!(:stoploss)
        end
      end
    end
  rescue => detail
    Notice.dingding("StopLoss：\n #{detail.message} \n #{detail.backtrace[0..5].join("\n")}")
  end
  sleep 10
end
