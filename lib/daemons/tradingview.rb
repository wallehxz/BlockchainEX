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

# tradingview 通知格式 #BTC_USDT|RSI1 <=> 70|market|ask
# subject= "#BTC_USDT|RSI1 <=> 70|step|bid"
def start_trade(subject)
  puts "[#{Time.now.to_s(:short)}] #{subject}"
  trading = subject.split('|')
  quote = trading[0].split('_')
  market = Market.find_by_quote_unit_and_base_unit(quote[0],quote[1])
  if market&.regulate&.fast_trade
    amount = market.regulate.fast_cash
    profit = market.regulate.fast_profit || 0.002
    side = trading[-1]
    if side == 'bid'
      puts "[#{Time.now.to_s(:short)}] staring new bid order"
      bid_order(market, amount, profit, subject)
    elsif side == 'ask'
      puts "[#{Time.now.to_s(:short)}] staring ask bid order"
      ask_order(market, amount, profit, subject)
    end
  end
end

def bid_order(market, amount, profit, subject)
  price = market.recent_price * (1 - profit)
  if subject =~ /(step)|(market)/
    puts "[#{Time.now.to_s(:short)}] #{market.full_name} bid #{$1} amount: #{amount}"
    market.send("#{$1}_price_bid".to_sym, amount)
  else
    puts "[#{Time.now.to_s(:short)}] #{market.full_name} bid limit amount: #{amount}"
    market.new_bid(price, amount)
  end
end

def ask_order(market,amount, profit, subject)
  price = market.recent_price * (1 + profit)
  if subject =~ /(step)|(market)/
    puts "[#{Time.now.to_s(:short)}] #{market.full_name} ask #{$1} amount: #{amount}"
    market.send("#{$1}_price_ask".to_sym, amount)
  else
    puts "[#{Time.now.to_s(:short)}] #{market.full_name} ask limit amount: #{amount}"
    aks_order = market.new_ask(price, amount)
  end
end

def stop_loss(subject)
  trading = subject.split('|')
  quote = trading[0].split('_')
  market = Market.find_by_quote_unit_and_base_unit(quote[0],quote[1])
  if market&.regulate&.fast_trade
    market.sync_fund
    funds = market.fund&.balance * 0.999
    price = market.recent_price
    ask_order = market.asks.create(price: price, amount: funds, category: 'chives', state: 'succ')
    ask_order.push_market_order
    ask_order.notice
    market.regulate.update(fast_trade: false)
  end
end

def build(subject)
  trading = subject.split('|')
  quote = trading[0].split('_')
  market = Market.find_by_quote_unit_and_base_unit(quote[0],quote[1])
  unless market&.regulate&.fast_trade
    market.regulate.update(fast_trade: true, support: market.recent_price * 0.9975)
    amount = market.regulate.retain
    market.step_price_bid(amount)
  end
end

while($running) do
  begin
    mails = Mail.all.select { |x| x.from[0] =~ /tradingview/ }
    mails.each do |email|
      if email.subject.include? '|'
        subject = email.subject
        topic = subject.delete(' ').split('#')[-1]
        Notice.dingding("[#{Time.now.to_s(:short)}] \n #{topic}")
        start_trade(topic) if topic =~ /(bid)|(ask)/
        stop_loss(topic) if topic =~ /stop_loss/
        build(topic) if topic =~ /build/
      end
    end
  rescue => detail
    Notice.dingding("TradingView：\n #{detail.message} \n #{detail.backtrace[0..5].join("\n")}")
  end
  sleep 10
end
