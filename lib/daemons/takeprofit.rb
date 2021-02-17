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
      total   = coin.all_funds
      freezing = coin.fund.freezing
      balance = coin.fund.balance
      _latest = coin.recent_price
      _profit = regul.resistance
      _support = regul.support
      _retain = regul.retain
      trends  = coin.get_ticker('1m', 2).kline_trends

      if total < _retain / 20.0
        regul.toggle!('takeprofit')
        content = "[#{Time.now.to_s(:short)}] #{coin.symbols} 关闭止盈"
        Notice.dingding(content)
      end

      if freezing > 0
        coin.ask_active_orders.map { |o| coin.undo_order(o['orderId']) }
      end

      if _latest > _profit && _latest * 0.998 > _support
        regul.update!(support: _latest * 0.998)
      end

      if _latest > _profit && trends[-1] < 0
        #如果价格大于预期收益，且开始下跌，则批量卖出
        _amount = _retain / 5.0
        if balance > _amount
          coin.step_price_ask(_amount)
        else
          coin.step_price_ask(balance)
        end
      elsif _latest < _support && trends[-1] < 0
        #如果价格低于止盈，则通过市价全部卖出阶梯卖出止损
        coin.market_price_ask(balance)
      end

      #设置止损单
      amount = coin.all_funds.to_d.round(coin&.regulate&.amount_precision || 4, :down)
      if amount > _retain / 20.0
        price  = regul.support.to_d.round(coin&.regulate&.price_precision || 4, :down)
        coin.sync_stop_order(price, price, amount)
        content = "[#{Time.now.to_s(:short)}] #{coin.symbols} 预售限价止损单\n\n" +
        "> 价格：#{price} #{coin.base_unit}\n\n" +
        "> 数量：#{amount} #{coin.quote_unit}"
        Notice.dingding(content)
      end

    end
  rescue => detail
    Notice.dingding("TakeProfit：\n #{detail.message} \n #{detail.backtrace[0..5].join("\n")}")
  end
  sleep 30
end
