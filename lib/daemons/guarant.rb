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
    Regulate.where(fast_trade: true).each do |regul|
      coin    = regul.market
      _loss   = regul.support
      _latest = coin.recent_price
      if _latest < _loss
        coin.sync_fund
        balance = coin.fund.balance
        if balance > 0.01
          coin.step_price_ask(balance)
          Notice.sms("\n 开启止损操作：\n> 数量: #{balance} \n> 价格: #{_latest} \n")
        end
      end
    end
  rescue => detail
    Notice.dingding("TradeBot：\n #{detail.message} \n #{detail.backtrace[0..5].join("\n")}")
  end
  sleep 10
end
