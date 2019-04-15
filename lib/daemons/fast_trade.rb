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
  if $market.market_index('15m',12)[4] < 0.5
    Notice.dingding("快频交易提醒： 发现15m 成交条件 #{$market.market_index('15m',12)}")
    if $market.market_index('1m',5)[4] > 1.382
      Notice.dingding("快频交易提醒： 发现 1m 成交条件 #{$market.market_index('15m',12)}")
      recent_price = $market.recent_price
      amount = trade_cash / recent_price
      $market.new_bid(recent_price, amount, 'fast')
    end
  end
end

def fast_profit
  $market.regulate&.fast_profit || 1.052
end

def sell_trade_order
  order = current_fast_order
  order_price = order.price
  recent_price = $market.recent_price
  if recent_price >= order_price * fast_profit
    ask_order = $market.new_ask(recent_price, order.amount, 'fast')
    if ask_order.state.succ?
      order.update_attributes(state: 120)
      order.sold_tip_with(ask_order)
    end
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
  sleep 60
end
