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


def start_hunter(btc)
  amount = btc.regulate.fast_cash
  quote_90 = btc.get_ticker('1m', 90)
  quote_90_c = quote_90.map{|x| x[4].to_f }
  quote_90_flow = quote_90.map {|k| (k[4].to_f - k[1].to_f).round(2)}

  price_min_bid(btc,amount,quote_90_c)
  price_max_ask(btc,quote_90_c)
  undo_exceed_orders(btc)
  bids_min30_not_match(btc)
  # bear_stop_loss(btc)
end

def price_min_bid(btc,amount,quote_90_c)
  if quote_90_c.min == quote_90_c[-1]
    profit = btc.regulate.fast_profit || 0.0015
    price = quote_90_c[-1] * (1 - profit)
    btc.new_bid(price, amount)
  end

  if quote_90_c.min == quote_90_c[-2]
    btc.step_price_bid(amount)
  end
end

def supplement_funds(btc, amount)
  btc.sync_fund
  if btc.fund.balance < btc.regulate.retain * 0.6
    num = (btc.regulate.retain * 0.6 - btc.fund.balance) / amount
    num.ceil.times {|i| btc.market_price_bid(amount) }
  end
end

def price_max_ask(btc,quote_90_c)
  if quote_90_c[-2] == quote_90_c.max
    batch_ask_orders(btc)
  end
end

def batch_ask_orders(btc)
  bids_orders = btc.bids.succ.order(price: :asc)
  bids_orders.each do |order|
    recent_price = btc.recent_price
    if recent_price > order.price + 100
      btc.market_price_ask(amount)
    end
  end
end

def undo_exceed_orders(btc)
  btc.sync_fund
  fund = btc.fund.balance
  quota = btc.regulate.retain
  if fund > quota
    btc.bid_active_orders.map do |order|
      btc.undo_order(order['orderId'])
      btc.bids.succ.where(price: order['price'].to_f).first&.update(state: 0)
    end
  end
end

def bids_min30_not_match(btc)
  orders = btc.bid_active_orders
  min30_orders = orders.select { |o| (Time.now - Time.at(o['time'] / 1000)) > 30.minute}
  min30_orders.map do |order|
    btc.undo_order(order['orderId'])
    btc.bids.succ.where(price: order['price'].to_f).first&.update(state: 0)
  end
end

def bear_stop_loss(btc)
  min_order = btc.bids.succ.order(price: :desc).first
  if min_order
    recent_price = btc.recent_price
    order_price = min_order.price
    if recent_price < order_price * (1 - 0.01)
      btc.market_price_ask(min_order.amount)
      min_order.update(state: 120)
    end
  end
end

while($running) do
  begin
    btc = Market.first
    start_hunter(btc) if btc&.regulate&.fast_trade
  rescue => detail
    Notice.dingding("羊毛党 Robot：\n #{detail.message} \n #{detail.backtrace[0..5].join("\n")}")
  end
  sleep 60
end
