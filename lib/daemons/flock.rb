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


def start_btc_hunter
  btc = Market.first
  amount = btc.regulate.fast_cash
  quote_90 = btc.get_ticker('1m', 90)
  quote_90_c = quote_90.map{|x| x[4].to_f }
  quote_90_flow = quote_90.map {|k| (k[4].to_f - k[1].to_f).round(2)}

  price_min_bid(btc,amount,quote_90_c)
  price_max_ask(btc,amount,quote_90_c,quote_90_flow)
end

def price_min_bid(btc,amount,quote_90_c)
  if quote_90_c.min == quote_90_c[-1]
    _price = quote_90_c[-1] * (1 - 0.0015)
    btc.new_bid(_price, amount)
  end

  if quote_90_c.min == quote_90_c[-2]
    _price = quote_90_c[-2] * (1 - 0.001)
    btc.new_bid(_price, amount)
  end
end

def price_max_ask(btc,amount,quote_90_c,quote_90_flow)
  profit = btc.bids.succ.last.price + 100
  if quote_90_flow[-1] < 0 && quote_90_c[-1] > profit
    btc.market_price_ask(amount)
    btc.bids.succ.last.update(state: 120)
  end
end

while($running) do
  begin
    start_btc_hunter
  rescue => detail
    Notice.dingding("羊毛党 Robot：\n #{detail.message} \n #{detail.backtrace[0..5].join("\n")}")
  end
  sleep 60
end
