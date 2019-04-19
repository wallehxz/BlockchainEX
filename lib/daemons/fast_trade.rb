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

def start_trading
  if current_fast_order
    sell_trade_order
  else
    buy_trade_order
  end
end

def support_level
  $market.regulate.support
end

def current_fast_order
  $market.bids.fast_order.succ.first
end

def trade_cash
  $market.regulate&.fast_cash
end

def buy_trade_order
  tickers_30m = $market.get_ticker('1m', 45)
  price_30m = tickers_30m.map { |x| x[4].to_f }
  extent = price_30m.last / price_30m.max
  # puts "#{$market.symbols} #{price_30m} 当前浮动比例 #{extent}"
  if extent > 0.98 && extent < 0.9925
    recent_price = $market.recent_price
    amount = trade_cash / recent_price
    $market.new_bid(recent_price, amount, 'fast')
  end
end

def fast_profit
  $market.regulate&.fast_profit || 1.02
end

def sell_trade_order
  order = current_fast_order
  order_price = order.price
  amount = order.amount
  recent_price = $market.recent_price
  tickers_3m = $market.get_ticker('1m', 3).map {|x| x[4].to_f }
  # puts "#{$market.symbols} 最新价 #{recent_price} 订单价 #{order_price} 变化趋势 #{tickers_3m}"
  if recent_price >= order_price * fast_profit
    sell_order(order, recent_price, amount)
  elsif tickers_3m[0] < tickers_3m[1] && tickers_3m[1] > tickers_3m[2] && recent_price > order_price * 1.012
    sell_order(order, recent_price, amount)
  elsif recent_price <= order_price * 0.98
    sell_order(order, recent_price, amount)
    $market.regulate.update(fast_trade: false)
    Notice.wechat("快频交易关闭提醒：#{$market.symbols} 暂停交易")
  end
end

def sell_order(order, recent_price, amount)
  ask_order = $market.new_ask(recent_price, amount, 'fast')
  if ask_order.state.succ?
    order.update_attributes(state: 120)
    order.sold_tip_with(ask_order)
  end
end

while $running
  begin
    Market.seq.includes(:regulate).each do |item|
      $market = item
      if item.regulate&.fast_trade
        start_trading
      end
    end
  rescue => detail
    Notice.dingding("快频交易错误提醒：\n #{detail.message} \n #{detail.backtrace[0..2].join("\n")}")
  end
  sleep 45
end
