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
  $market_range.regulate&.range_profit || 1.0618
end

def buy_trade_order
  kline = $market_range.get_ticker('5m', 72).tickers_to_kline
  volumes = kline.map {|x| x[4] }
  prices = kline.map {|x| x[3] }
  recent_price = $market_range.recent_price

  if prices.min == prices[-2]
    $market_range.sync_cash
    if $market_range.cash.balance > trade_price
      amount = trade_cash / recent_price
      $market_range.new_bid(recent_price, amount, 'range')
    end
  elsif volumes.max == volumes[-2] && kline[-2][1] > 0
    $market_range.sync_cash
    if $market_range.cash.balance > trade_price
      amount = trade_cash / recent_price
      $market_range.new_bid(recent_price, amount, 'range')
    end
  end
end

def sell_trade_order
  order = current_range_order
  order_price = order.price
  amount = order.amount
  recent_price = $market_range.recent_price
  prices_6h = $market_range.get_ticker('5m', 72).map{|x| x[4].to_f}
  if recent_price > order_price && prices_6h[-3] == prices_6h.max
    ask_order = $market_range.new_ask(recent_price, amount, 'range')
    if ask_order.state.succ?
      order.update_attributes(state: 120)
      order.sold_tip_with(ask_order)
    end
  end
  if recent_price > order_price * range_profit
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
    Notice.dingding("支阻位错误提醒：\n 交易对：#{$market_range.symbols} \n #{detail.message} \n #{detail.backtrace[0..2].join("\n")}")
  end
  sleep 200
end
