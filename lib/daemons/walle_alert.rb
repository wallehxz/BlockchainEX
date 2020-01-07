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

while($running) do
  begin
    alerts = Mail.all.select { |x| x.from[0] =~ /tradingview/ }
    alerts.each do |alert|
      if alert.subject.include? '|'
        Notice.sms(string)
        string = alert.subject.split('|')[1..-1]
        quote = string[0].split('_')
        market = Market.where(quote_unit: quote[0], base_unit: quote[1]).first
        market.indicators.create(name: string[1], created_at: alert.date) if market
      end
    end
  rescue => detail
    Notice.dingding("指标接收工人：\n #{detail.message} \n #{detail.backtrace[0..2].join("\n")}")
  end
  sleep 5
end
