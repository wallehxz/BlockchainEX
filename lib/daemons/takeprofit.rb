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
      coin.sync_fund
      balance = coin.fund.balance
      _latest = coin.recent_price
      _cost   = coin.avg_cost
      _profit = regul.resistance
      _support = regul.support
      _retain = regul.retain
      trends  = coin.get_ticker('1m', 2).kline_trends

      if balance < _retain / 20.0
        regul.toggle!('takeprofit')
        content = "[#{Time.now.to_s(:short)}] #{coin.symbols} 关闭止盈"
        Notice.dingding(content)
      end

      if _latest > _profit && trends[-1] < 0
        #如果价格大于预期收益，且开始下跌，则批量卖出
        _amount = _retain / 5.0
        if balance > _amount
          coin.step_price_ask(_amount)
        else
          coin.market_price_ask(balance)
        end
      elsif _latest < _support
        #如果价格已经跌过成本，则通过大量阶梯卖出止损
        _amount = _retain / 4.0
        if balance > _amount
          coin.step_price_ask(_amount)
        else
          coin.market_price_ask(balance)
        end
      end

      if _latest > _profit && _latest * 0.998 > _support
        regul.update!(support: _latest * 0.998)
      end

    end
  rescue => detail
    Notice.dingding("TakeProfit：\n #{detail.message} \n #{detail.backtrace[0..5].join("\n")}")
  end
  sleep 10
end
