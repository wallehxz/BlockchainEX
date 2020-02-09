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

def start_trade(market, side)
  amount = market.regulate.fast_cash || 1
  market.send("step_price_#{side}".to_sym, amount)
end

while($running) do
  begin
    alerts = Mail.all.select { |x| x.from[0] =~ /tradingview/ }
    alerts.each do |alert|
      if alert.subject.include? '|'
        Notice.sms(alert.subject)
        string = alert.subject.split('|')
        quote = string[0].split('_')
        side = string[-1]
        market = Market.where(quote_unit: quote[0], base_unit: quote[1]).first
        trade = side.in?(['ask','bid']) && market.regulate.fast_trade
        start_trade(market, side) if market && trade
      end
    end
  rescue => detail
    Notice.dingding("指标Robot：\n #{detail.message} \n #{detail.backtrace[0..2].join("\n")}")
  end
  sleep 10
end
