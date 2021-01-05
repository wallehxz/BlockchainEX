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
  _latest = market.recent_price
  price = _latest * (1 - profit)
  market.regulate.update(cost: _latest * 0.998)
  if subject =~ /(step)|(market)/
    puts "[#{Time.now.to_s(:short)}] #{market.full_name} bid #{$1} amount: #{amount}"
    market.send("#{$1 || $2}_price_bid".to_sym, amount)
  else
    puts "[#{Time.now.to_s(:short)}] #{market.full_name} bid limit amount: #{amount}"
    market.new_bid(price, amount)
  end
end

def ask_order(market,amount, profit, subject)
  price = market.recent_price * (1 + profit)
  if subject =~ /(step)|(market)/
    puts "[#{Time.now.to_s(:short)}] #{market.full_name} ask #{$1} amount: #{amount}"
    market.send("#{$1 || $2}_price_ask".to_sym, amount)
  else
    puts "[#{Time.now.to_s(:short)}] #{market.full_name} ask limit amount: #{amount}"
    aks_order = market.new_ask(price, amount)
  end
end

def stoploss(subject)
  trading = subject.split('|')
  quote = trading[0].split('_')
  market = Market.find_by_quote_unit_and_base_unit(quote[0],quote[1])
  regul = market.regulate
  unless regul.stoploss
    regul.toggle!(:stoploss)
    content = "#{market.symbols} 开启止损 #{Time.now.to_s(:short)}"
    Notice.dingding(content)
  end

  if regul.fast_trade
    regul.toggle!(:fast_trade)
    content = "#{market.symbols} 关闭高频交易 #{Time.now.to_s(:short)}"
    Notice.dingding(content)
  end
  Daemon.start('stoploss')
end

def takeprofit(subject)
  trading = subject.split('|')
  quote = trading[0].split('_')
  market = Market.find_by_quote_unit_and_base_unit(quote[0],quote[1])
  regul = market.regulate
  unless regul.takeprofit
    cur_price = market.recent_price
    regul.toggle!(:takeprofit)
    regul.update(support: cur_price, resistance: cur_price * 1.005)
    content = "#{market.symbols} 开启止盈 #{Time.now.to_s(:short)} 止损价更新为 #{cur_price}"
    Notice.dingding(content)
  end
  Daemon.start('stoploss')
end

def build(subject)
  trading = subject.split('|')
  quote   = trading[0].split('_')
  market  = Market.find_by_quote_unit_and_base_unit(quote[0],quote[1])
  regul   = market&.regulate
  regul.toggle!(:fast_trade) unless regul.fast_trade
  regul.toggle!(:chasedown)  unless regul.chasedown
  content = "#{market.symbols} 开启高频交易,开启追跌交易 #{Time.now.to_s(:short)}"
  Notice.dingding(content)
  amount = regul.retain / 4.0
  market.step_price_bid(amount)
end

def all_in(subject)
  trading = subject.split('|')
  quote = trading[0].split('_')
  market = Market.find_by_quote_unit_and_base_unit(quote[0],quote[1])
  if market&.regulate&.fast_trade
    amount = market.regulate.retain
    market.market_price_bid(amount)
  end
end

def macd(subject)
  if subject.match(/macd-?\d+/)
    subject.match(/macd-?\d+/)[0].match(/-?\d+/)[0].to_i
  end
end

while($running) do
  begin
    mails = Mail.all.select { |x| x.from[0] =~ /tradingview/ } rescue []
    mails.each do |email|
      if email.subject.include? '#'
        subject = email.subject
        topic = subject.delete(' ').split('#')[-1]
        Notice.dingding("[#{Time.now.to_s(:short)}] \n #{topic}")
        start_trade(topic) if topic =~ /(bid)|(ask)/
        build(topic) if topic =~ /build/
        all_in(topic) if topic =~ /all_in/
        stoploss(topic) if topic =~ /stop/
        takeprofit(topic) if topic =~ /take/
      end
    end
  rescue => detail
    Notice.dingding("TradingView：\n #{detail.message} \n #{detail.backtrace[0..5].join("\n")}")
  end
  sleep 10
end
