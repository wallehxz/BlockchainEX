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
  coin.sync_fund
  _regul     = coin.regulate
  _retain    = _regul.retain
  balance    = coin.fund.balance
  support    = _regul.support
  resistance = _regul.resistance
  cost       = _regul.cost
  recent     = coin.recent_price

  if recent > resistance && balance > _retain * 0.75
    coin.on_takeprofit
    content = "[#{Time.now.to_s(:short)}] #{coin.symbols} 行情价格上涨预期收益 #{resistance} 开启止盈"
    _regul.update!(support: recent * 0.9975)
    Notice.dingding(content)
  end

  if recent < cost && balance > _retain * 0.5
    coin.on_stoploss
    content = "[#{Time.now.to_s(:short)}] #{coin.symbols} 行情价格下跌成本线 #{cost} 开启止损"
    Notice.dingding(content)
  end
end

while($running) do
  begin
    Regulate.where(fast_trade: true).each do |regul|
      start_hunter(regul.market)
    end
  rescue => detail
    Notice.exception(detail, "Deamon FastTrade")
  end
  sleep 60
end
