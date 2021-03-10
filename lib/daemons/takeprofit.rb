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
        break
      end

      if freezing > 0
        stop_price = coin.ask_active_orders[0].symbolize_keys[:stopPrice]
        if _support > stop_price || _latest < stop_price
          coin.ask_active_orders.map { |o| coin.undo_order(o['orderId']) }
        end
      end

      if _latest * 0.9995 > _support
        regul.update!(support: _latest * 0.9995)
      end

      if _latest < _support && trends[-1] < 0
        coin.market_price_ask(balance)
      end

      #设置止损单
      amount = coin.all_funds.to_d.round(coin&.regulate&.amount_precision || 4, :down)
      freezing = coin.fund.freezing
      if freezing == 0 && amount > 0
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
  sleep 60
end
