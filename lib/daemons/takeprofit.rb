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
    Regulate.all.each do |regul|
      coin    = regul.market
      _latest = coin.recent_price
      _profit = regul.support
      if _latest < _profit
        coin.sync_fund
        balance = coin.fund.balance
        if balance > 1
          coin.step_price_ask(regul.fast_cash)
        else
          coin.step_price_ask(balance * 0.998)
          coin.stop_daemon('takeprofit')
        end
      end
    end
  rescue => detail
    Notice.dingding("Guarant：\n #{detail.message} \n #{detail.backtrace[0..5].join("\n")}")
  end
  sleep 10
end