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
  tickers_30m = $market.get_ticker('3m', 10)
  price_30m = tickers_30m.map { |x| x[4].to_f }
  extent = price_30m.last / price_30m.max
  kline = tickers_30m.tickers_to_kline
  down_entity = kline.select {|x| x[1] < 0 }
  up_entity = kline.select {|x| x[1] > 0 }
  recent_price = $market.recent_price
  if recent_price < $market.min_16 * 1.0075 && recent_price > $market.min_16
    amount = trade_cash / recent_price
    $market.new_bid(recent_price, amount, 'fast')
  elsif extent < 0.992
    if down_entity.size < 5
      amount = trade_cash / ( recent_price * 0.9935 )
      $market.new_bid(recent_price, amount, 'fast')
    elsif down_entity.size == 5
      amount = trade_cash / ( recent_price * 0.9985 )
      $market.new_bid(recent_price, amount, 'fast')
    elsif [6,7].include? down_entity.size
      amount = trade_cash / ( recent_price * 0.9935 )
      $market.new_bid(recent_price, amount, 'fast')
    elsif down_entity.size == 8
      amount = trade_cash / ( recent_price * 0.99 )
      $market.new_bid(recent_price, amount, 'fast')
    end
  end
end

def fast_profit
  $market.regulate&.fast_profit || 1.02
end

def sell_trade_order
  order = current_fast_order
  order_price = order.price
  amount = order.amount
  if Time.now - order.created_at > 7.minute
    tickers_12m = $market.get_ticker('3m', 4)
    recent_price = $market.recent_price
    kline = tickers_12m.tickers_to_kline
    down_entity = kline.select {|x| x[1] < 0 }
    up_entity = kline.select {|x| x[1] > 0 }
    if recent_price > order_price
      if down_entity.size == 1 && kline[-1][1] < 0 && recent_price > order_price * fast_profit
        sell_order(order, recent_price, amount)
      elsif down_entity.size == 2 && kline[-1][1] < 0 && recent_price > order_price * 1.0075
        sell_order(order, recent_price , amount)
      elsif down_entity.size > 2
        sell_order(order, recent_price , amount)
      end
    elsif kline[-1][1] < 0 && recent_price < order_price * 0.985 #强行止损
      sell_order(order, recent_price , amount)
    end
  else
    tickers_5m = $market.get_ticker('1m', 5)
    kline = tickers_5m.tickers_to_kline
    recent_price = $market.recent_price
    down_entity = kline.select {|x| x[1] < 0 }
    if down_entity.size > 2 && kline[-1][1] < 0 && recent_price > order_price * 1.005
      sell_order(order, recent_price , amount)
    end
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
