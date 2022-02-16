class Stoploss
  class << self
    def binance_trade(regul)
      coin    = regul.market
      coin.sync_fund
      balance = coin.fund.balance

      if balance < regul.retain * 0.01
        coin.market_price_ask(balance)
        coin.off_stoploss
        content = "#{regul.market.symbols} 关闭止损 #{Time.now.to_s(:short)}"
        Notice.dingding(content)
      end

      if coin.get_price[:bid] > regul.cost
        amount = regul.fast_cash
        coin.step_price_ask(amount)
      end

      if coin.get_price[:bid] < regul.cost
        amount = regul.fast_cash
        coin.market_price_ask(amount)
      end
    end

    def future_trade(regul)
      market  = regul.market
      support = -regul.support
      price   = market.get_price[:ask]
      long    = market.long_position
      if market.cma_fast < 0 && long['unrealizedProfit'].to_f < support
        market.new_ping_long(price, long['positionAmt'].to_f.abs)
      end

      short = market.short_position
      if market.cma_fast > 0 && short['unrealizedProfit'].to_f < support
        market.new_ping_short(price, short['positionAmt'].to_f.abs)
      end
    end

    def start
      begin
        Regulate.where(stoploss: true).each do |regul|
          future_trade(regul)  if regul.market.source == 'future'
          binance_trade(regul) if regul.market.source == 'binance'
        end
      rescue => detail
        Notice.exception(detail, "Deamon StopLoss")
      end
    end
  end
end