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
    Regulate.where(takeprofit: true).each do |regul|
      market = regul.market
      profit = regul.cash_profit
      cost   = regul.cost
      price  = market.get_price[:bid]
      amount = regul.fast_cash

      market.sync_fund
      balance = coin.fund.balance
      retain  = regul.retain
      if balance < retain * 0.001
        market.off_takeprofit
        content = "[#{Time.now.to_s(:short)}] #{market.symbols} 持币已经卖出"
        Notice.dingding(content)
      end

      if price > cost + profit
        trends = market.get_ticker('1m', 1).kline_trends[0]
        if trends > 0
          market.step_price_ask(amount * 0.5)
          market.market_price_ask(amount * 0.5)
        else
          market.market_price_ask(amount * 0.5)
        end
      end

      if market.indicators.macds.last.created_at > Time.now - 10.minute
        macds = market.indicators.macds.last(3)
        macds_m = macds.map(&:macd_m)
        if macds_m.max == macds_m[1] && price > cost
          market.market_price_ask(amount * 0.5)
        end

        if macds_m.min == macds_m[-1] && price > cost
          market.market_price_ask(amount * 0.5)
        end
      end

    end
  rescue => detail
    Notice.exception(detail, "Deamon TakeProfit")
  end
  sleep 25
end
