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
  trends = market.get_ticker('1m', 2).kline_trends
  if trends.max < 0
    amount = market.regulate.fast_cash / 2.0
    price  = market.recent_price * (1 - market.regulate.fast_profit)
    market.new_bid(price, amount)
  elsif trends[0] < 0 && trends[1] > 0
    amount = market.regulate.fast_cash / 4.0
    market.step_price_bid(amount)
  end
end

while($running) do
  begin
    Regulate.where(chasedown: true).each do |regul|
      coin = regul.market
      bid_orders = coin.bid_active_orders

      if bid_orders.present?
        bid_order = bid_orders[0]
        bid_time = bid_order['time'] / 1000
        if Time.now.to_i - bid_time > 100
          coin.undo_order(bid_order['orderId'])
          chase_order(coin)
        end
      else
        chase_order(coin)
      end
    end
  rescue => detail
    Notice.dingding("Chasedown：\n #{detail.message} \n #{detail.backtrace[0..5].join("\n")}")
  end
  sleep 60
end
