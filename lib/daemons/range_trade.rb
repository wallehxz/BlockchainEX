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
  if current_range_order
    sell_trade_order
  else
    buy_trade_order
  end
end

def current_range_order
  $market_range.bids.range_order.succ.first
end

def trade_cash
  $market_range.regulate&.range_cash
end

def range_profit
  $market_range.regulate&.fast_profit || 1.0618
end

def buy_trade_order
  cds_price = $market_range.get_ticker('30m', 145)[0..-2].map {|x| x[4].to_f}
  recent_price = $market_range.recent_price
  min_price = cds_price.min
  if recent_price > min_price && recent_price < min_price * 1.005
    amount = trade_cash / recent_price
    $market_range.new_bid(recent_price, amount, 'range')
  end
end

def sell_trade_order
  order = current_range_order
  order_price = order.price
  amount = order.amount
  recent_price = $market_range.recent_price
  cds_price = $market_range.get_ticker('30m', 145)[0..-2].map {|x| x[4].to_f}
  max_price = cds_price.max
  if recent_price > recent_price * 0.995 || recent_price > order_price * range_profit
    ask_order = $market_range.new_ask(recent_price, amount, 'range')
    if ask_order.state.succ?
      order.update_attributes(state: 120)
      order.sold_tip_with(ask_order)
    end
  end
end

while $running
  begin
    Market.seq.includes(:regulate).each do |item|
      $market_range = item
      if item.regulate&.range_trade
        start_trading
      end
    end
  rescue => detail
    Notice.dingding("支阻位错误提醒：\n 时间：#{Time.now} \n #{detail.backtrace.select {|x| x.include?('releases')}.join("\n")}")
  end
  sleep 200
end
