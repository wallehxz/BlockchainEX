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

def start_trade(subject)
  str_arr = subject.delete(' ').split('|')
  quote = str_arr[0].split(':').last.split('_')
  market = Market.find_by_quote_unit_and_base_unit(quote[0],quote[1])
  if market&.regulate&.fast_trade
    amount = market&.regulate.fast_cash
    profit = market&.regulate.fast_profit || 0.002
    side = str_arr[-1]
    if side == 'bid'
      bid_order(market, amount, profit, subject)
    elsif side == 'ask'
      ask_order(market, amount, profit, subject)
    end
  end
end

def bid_order(market, amount, profit, subject)
  price = market.recent_price * (1 - profit)
  if subject =~ /(step)|(market)/
    market.send("#{$1}_price_bid".to_sym, amount)
  else
    market.new_bid(price, amount)
  end
end

def ask_order(market,amount, profit, subject)
  price = market.recent_price * (1 + profit)
  if subject =~ /(step)|(market)/
    market.send("#{$1}_price_ask".to_sym, amount)
  else
    market.new_ask(price, amount)
  end
  market.bids.succ.order(price: :desc).last&.update(state: 120)
end

while($running) do
  begin
    mails = Mail.all.select { |x| x.from[0] =~ /tradingview/ }
    mails.each do |email|
      if email.subject.include? '|'
        subject = email.subject
        Notice.dingding("[#{Time.now.strftime('%H:%M')}] \n #{subject}")
        start_trade(subject) if subject =~ /(bid)|(ask)/
      end
    end
  rescue => detail
    Notice.dingding("TradingView Robot：\n #{detail.message} \n #{detail.backtrace[0..5].join("\n")}")
  end
  sleep 10
end
