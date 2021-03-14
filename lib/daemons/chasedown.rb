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

# TODO
# 判断当前是否有之前的订单，如果没有，则拉取最新的行情，如果K线是下跌，且开始回弹，则追加订单

def chase_order(coin)
  trends = coin.get_ticker('1m', 2).kline_trends
  if trends[0] < 0 && trends[1] > 0
    coin.bid_active_orders.map { |o| coin.undo_order(o['orderId']) }
    amount = coin.regulate.fast_cash
    price  = coin.ticker['bidPrice'].to_f
    coin.new_bid(price, amount)
  end
end

def all_to_off(coin)
  coin.sync_fund
  balance = coin.fund.balance
  _regul  = coin.regulate
  retain  = _regul.retain
  if balance > retain * 0.9
    _regul.take_profit_cost
    if _regul.chasedown
      _regul.toggle!(:chasedown)
      content = "[#{Time.now.to_s(:short)}] #{coin.symbols} 已经买入足够数量 关闭追跌"
      Notice.dingding(content)
    end
  end
end

while($running) do
  begin
    Regulate.where(chasedown: true).each do |regul|
      coin = regul.market
      chase_order(coin)
      all_to_off(coin)
    end
  rescue => detail
    Notice.dingding("Chasedown：\n #{detail.message} \n #{detail.backtrace[0..5].join("\n")}")
  end
  sleep 45
end
