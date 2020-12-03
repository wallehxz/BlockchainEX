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

def chase_order(market)
  trends = market.get_ticker('1m', 3).kline_trends
  if trends.max < 0
    amount = market.regulate.fast_cash
    price  = market.recent_price * (1 - market.regulate.fast_profit)
    market.new_bid(price, amount)
  elsif trends[0] > 0 && trends[1..2].max < 0
    amount = market.regulate.fast_cash / 2
    price  = market.recent_price * (1 - market.regulate.fast_profit / 2)
    market.new_bid(price, amount)
  end
end

def all_to_off(coin)
  coin.sync_fund
  balance = coin.fund.balance
  _regul = coin.regulate
  retain = _regul.retain
  if balance > retain * 0.91
    if _regul.chasedown
      _regul.toggle!('chasedown')
      content = "[#{Time.now.to_s(:short)}] #{coin.symbols} 已经买入足够数量 关闭追跌"
      Notice.dingding(content)
    end
  end
end

while($running) do
  begin
    Regulate.where(chasedown: true).each do |regul|
      coin = regul.market
      all_to_off(coin)
      bid_orders = coin.bid_active_orders
      if bid_orders.present?
        bid_order = bid_orders[0]
        coin.undo_order(bid_order['orderId'])
        chase_order(coin)
      else
        chase_order(coin)
      end
    end
  rescue => detail
    Notice.dingding("Chasedown：\n #{detail.message} \n #{detail.backtrace[0..5].join("\n")}")
  end
  sleep 60
end
