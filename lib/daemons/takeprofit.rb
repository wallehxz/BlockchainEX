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
      coin    = regul.market
      _latest = coin.recent_price
      _profit = regul.resistance
      _loss   = regul.support
      _retain = regul.retain

      if _latest > _profit
        #如何当前价格已经大于预期收益，则通过小量阶梯价慢慢卖出止盈
        coin.sync_fund
        balance = coin.fund.balance
        _amount = _retain / 10.0
        if balance > _amount
          coin.step_price_ask(_amount)
        else
          coin.market_price_ask(balance)
        end
      elsif _latest < _loss
        #如果价格已经已经跌幅过大，则通过大量阶梯卖出止损
        coin.sync_fund
        balance = coin.fund.balance
        _amount = _retain / 5.0
        if balance > _amount
          coin.step_price_ask(_amount)
        else
          coin.market_price_ask(balance)
        end
      end

      if coin.fund.balance < _retain / 20.0
        regul.toggle!('takeprofit')
        content = "[#{Time.now.to_s(:short)}] #{regul.market.symbols} 关闭止盈"
        Notice.dingding(content)
      end

    end
  rescue => detail
    Notice.dingding("TakeProfit：\n #{detail.message} \n #{detail.backtrace[0..5].join("\n")}")
  end
  sleep 10
end
