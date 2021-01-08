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

def binance_usdt_tickers
  ticker_url = 'https://api.binance.com/api/v1/ticker/24hr'
  res = Faraday.get do |req|
    req.url ticker_url
  end
  markets = JSON.parse(res.body)
  usdt_marts = []
  markets.each do |quote|
    usdt_quot = (quote['symbol'] =~ /USDT/) || 0
    if usdt_quot > 2
      usdt_marts << quote
    end
  end
  usdt_marts = usdt_marts.select {|x| !x['symbol'].include?('UPUSDT')}
  usdt_marts = usdt_marts.select {|x| !x['symbol'].include?('DOWNUSDT')}
  usdt_marts.sort {|x, y| y['priceChangePercent'].to_f <=> x['priceChangePercent'].to_f }
end

while($running) do
  begin
    tip = ''
    tickers = binance_usdt_tickers
    (tickers[0..2] + tickers[-3..-1]).each do |quote|
      tip << "#{quote['symbol']} 涨幅[#{quote['priceChangePercent']}],报价[#{quote['lastPrice'].to_f}]\n"
    end
    Notice.dingding(tip)
  rescue => detail
    Notice.dingding("价格波动 Robo：\n 交易对：#{$market.symbols} \n #{detail.message} \n #{detail.backtrace[0..2].join("\n")}")
  end
  sleep 60 * 60
end
