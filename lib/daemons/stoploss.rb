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
  rescue => detail
    Notice.exception(detail, "Deamon StopLoss")
  end
  sleep 29
end
