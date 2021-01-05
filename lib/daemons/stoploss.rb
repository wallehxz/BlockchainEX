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
      coin.off_trade if regul.fast_trade || regul.range_trade || regul.chasedown
      coin.sync_fund
      balance = coin.fund.balance

      if balance < regul.retain / 20.0
        coin.market_price_ask(balance)
        regul.toggle!(:stoploss)
        content = "#{regul.market.symbols} 关闭止损 #{Time.now.to_s(:short)}"
        Notice.dingding(content)
      end

      amount = regul.retain / 4.0
      if balance > amount
        coin.step_price_ask(amount)
      else
        coin.market_price_ask(balance)
      end
    end
  rescue => detail
    Notice.dingding("StopLoss：\n #{detail.message} \n #{detail.backtrace[0..5].join("\n")}")
  end
  sleep 10
end
