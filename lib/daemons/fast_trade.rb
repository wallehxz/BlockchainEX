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
  unless current_fast_order
    buy_trade_order if sell_order_done?
  else
    sell_trade_order if buy_order_done?
  end
end

def support_level
  $market.regulate.support
end

def current_fast_order
  $market.bids.fast_order.succ.first
end

def buy_cooling?
  (Time.now - $market.asks.fast_order.succ.last.created_at) > 5.minute rescue true
end

def sell_cooling?
  (Time.now - current_fast_order.created_at) > 9.minute rescue true
end

def buy_order_done?
  $market.sync_cash
  if $market.cash.freezing > 10
    return false
  end
  true
end

def sell_order_done?
  $market.sync_fund
  if $market.fund.freezing > 10
    return false
  end
  true
end

def trade_cash
  $market.sync_cash
  cash = $market.cash.balance
  fast_cash = $market.regulate&.fast_cash
  cash > fast_cash ? fast_cash : 0
end

def fast_profit
  $market.regulate&.fast_profit || 1.02
end

def buy_trade_order
  #判断当前
  candles_1h = $market.get_ticker('3m', 20)
  prices = candles_1h.map {|x| x[4].to_f }
  klines = candles_1h.tickers_to_kline
  _fir_price = prices[0]
  _las_price = prices[-1]
  _min_price = prices.min
  _max_price = prices.max
  if prices[-3] == _min_price && klines[-2][1] > klines[-2][3] * 0.0015
    if (_las_price / _fir_price) < 0.985
      _price = _las_price * 0.9985
      amount = trade_cash / _price
      $market.new_bid(_price, amount, 'fast')
    elsif (_las_price / _max_price) < 0.97
      _price = _las_price * 0.9985
      amount = trade_cash / _price
      $market.new_bid(_price, amount, 'fast')
    end
  end
end

def sell_trade_order
  bid_order = current_fast_order
  _price = bid_order.price
  $market.sync_fund
  _fund = $market.fund.balance
  _amount = bid_order.amount
  _amount = _fund > _amount ? _amount : _fund * 0.999
  candles_12m = $market.get_ticker('3m', 4)
  kline_12m = candles_12m.tickers_to_kline
  _las_price = kline_12m[-1][3]

  if _las_price > _price * 1.02
    sell_order(bid_order, _las_price, _amount)
  end

  if kline_12m[-1][1] < 0
    if _las_price > _price * fast_profit
      sell_order(bid_order, _las_price, _amount)
    end

    if kline_12m.select {|x| x[1] < 0}.size == 2 && _las_price > _price * 1.0075
      sell_order(bid_order, _las_price, _amount)
    end

    if _las_price < _price
      stop_loss_order(bid_order, _las_price, _amount)
    end
  end

end

def sell_order(order, price, amount)
  ask_order = $market.new_ask(price, amount, 'fast')
  if ask_order.state.succ?
    order.update_attributes(state: 120)
    order.sold_tip_with(ask_order)
  end
end

def stop_loss_order(order, price, amount)
  # $market.regulate.update(fast_trade: false)
  stop_order = $market.asks.create(price: price, amount: amount, category: 'fast', state: 'succ')
  result = stop_order.push_market_order
  if result['state'] != 200
    stop_order.update_attributes(state: result['state'], cause: result['cause'])
  else
    order.update_attributes(state: 120)
    order.sold_tip_with(stop_order)
  end
end

def day_ma10_up?
  tickers_10d = $market.get_ticker('1d', 10)
  prices = tickers_10d.map {|x| x[4].to_f }
  _cur_price = prices.last
  _ma10_price = prices.sum / 10
  if _cur_price > _ma10_price
    return true
  end
  false
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
  sleep 60
end
