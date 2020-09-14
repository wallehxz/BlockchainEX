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
    Regulate.where(takeprofit: true).each do |regul|
      coin    = regul.market
      _latest = coin.recent_price
      _profit = regul.support
      amount = regul.retain / 5.0
      if _latest < _profit
        coin.sync_fund
        balance = coin.fund.balance
        if balance < regul.retain / 20.0
          regul.toggle!('takeprofit')
          content = "#{market.symbols} 关闭止盈 #{Time.now.to_s(:short)}"
          Notice.dingding(content)
        end
        if balance > amount
          coin.market_price_ask(amount)
        else
          coin.market_price_ask(balance)
        end
      end
    end
  rescue => detail
    Notice.dingding("TakeProfit：\n #{detail.message} \n #{detail.backtrace[0..5].join("\n")}")
  end
  sleep 10
end
