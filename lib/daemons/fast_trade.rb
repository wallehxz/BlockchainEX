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
    buy_trade_order if order_cooling?
  end
end

def support_level
  $market.regulate.support
end

def current_fast_order
  $market.bids.fast_order.succ.first
end

def order_cooling?
  (Time.now - $market.asks.fast_order.succ.last.created_at) > 7.minute rescue true
end

def trade_cash
  $market.regulate&.fast_cash
end

def buy_trade_order
  tickers_45m = $market.get_ticker('3m', 15)
  price_45m = tickers_45m.map { |x| x[4].to_f }
  extent = price_45m.last / price_45m.max
  kline = tickers_45m.tickers_to_kline
  down_entity = kline.select {|x| x[1] < 0 }
  up_entity = kline.select {|x| x[1] > 0 }
  recent_price = $market.recent_price
  market_index = $market.market_index('3m', 40)[4]

  if (extent < 0.9925 && market_index > 0.6)
    $market.sync_cash
    if $market.cash.balance > trade_cash
      if [5,6].include? down_entity.size
        trade_price = recent_price * 0.9985
        amount = trade_cash / trade_price
        $market.new_bid(trade_price, amount, 'fast')

      elsif down_entity.size == 7
        trade_price = recent_price * 0.9985
        amount = trade_cash / trade_price
        $market.new_bid(trade_price, amount, 'fast')

      elsif [8,9,10].include? down_entity.size
        trade_price = recent_price * 0.9965
        amount = trade_cash / trade_price
        $market.new_bid(trade_price, amount, 'fast')

      elsif down_entity.size > 10
        trade_price = recent_price * 0.9925
        amount = trade_cash / trade_price
        $market.new_bid(trade_price, amount, 'fast')
      end
    end
  end

end

def fast_profit
  $market.regulate&.fast_profit || 1.02
end

def sell_trade_order
  order = current_fast_order
  order_price = order.price
  $market.sync_fund
  fund = $market.fund.balance
  amount = fund > order.amount ? order.amount : fund

  if Time.now - order.created_at > 7.minute
    tickers_15m = $market.get_ticker('3m', 5)
    recent_price = $market.recent_price
    kline = tickers_15m.tickers_to_kline
    down_entity = kline.select {|x| x[1] < 0 }
    up_entity = kline.select {|x| x[1] > 0 }
    market_index = $market.market_index('5m', 30)[4]

    if recent_price > order_price
      if kline[-1][1] < 0 && recent_price > order_price * fast_profit
        sell_order(order, recent_price, amount)
      elsif recent_price > order_price * 1.015
        sell_order(order, recent_price , amount)
      end
    end

    if recent_price < order_price * 975
      sell_order(order, recent_price , amount)
      $market.regulate.update(fast_trade: false)
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
    Notice.dingding("快频交易错误提醒：\n 交易对：#{$market.symbols} \n #{detail.message} \n #{detail.backtrace[0..2].join("\n")}")
  end
  sleep 45
end
