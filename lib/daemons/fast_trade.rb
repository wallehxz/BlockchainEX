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
  up_with_market
  down_with_market
end

def up_with_market
  if $market.market_index('1h',24)[4] > 0.9
    if $market.market_index('15m',16)[4] < 0.45
      if $market.market_index('1m',7)[4] > 1.33
        recent_price = $market.recent_price
        amount = trade_cash / recent_price
        $market.new_bid(recent_price, amount, 'fast')
      end
    end
  end
end

def down_with_market
  if $market.market_index('1h',24)[4] < 0.5
    if $market.market_index('30m',16)[4] < 0.32
      if $market.market_index('1m',7)[4] > 1.33
        recent_price = $market.recent_price
        amount = trade_cash / recent_price
        $market.new_bid(recent_price, amount, 'fast')
      end
    end
  end
end

def fast_profit
  $market.regulate&.fast_profit || 1.0382
end

def sell_trade_order
  order = current_fast_order
  order_price = order.price
  amount = order.amount
  recent_price = $market.recent_price
  if recent_price >= order_price * fast_profit
    sell_order(order, recent_price, amount)
  elsif $market.market_index('1m',7)[4] < 0.5
    if recent_price > order_price * 1.012
      sell_order(order, recent_price, amount)
    end
  elsif recent_price <= order_price * 0.995
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
    Notice.dingding("快频交易错误提醒：\n #{detail.backtrace.join("\n")}")
  end
  sleep 100
end
