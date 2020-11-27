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
  _retain = _regu.retain
  coin.sync_fund
  balance = coin.fund.balance

  if balance > _retain * 0.6
    unless coin.regulate.takeprofit
      coin.regulate.toggle!('takeprofit')
      content = "[#{Time.now.to_s(:short)}] #{coin.symbols} 持有数量达到60% 开启止盈"
      Notice.dingding(content)
    end
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
