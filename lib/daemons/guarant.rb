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
        if balance > 1
          coin.market_price_ask(balance / 3)
          Notice.sms("\n 开启止损操作：\n> 数量: #{balance / 3} \n> 价格: #{_latest} \n")
        else
          coin.market_price_ask(balance * 0.998)
          Notice.sms("\n 开启止损操作：\n> 数量: #{balance} \n> 价格: #{_latest} \n")
          regul.update(fast_trade: false)
        end
      end
    end
  rescue => detail
    Notice.dingding("Guarant：\n #{detail.message} \n #{detail.backtrace[0..5].join("\n")}")
  end
  sleep 15
end
