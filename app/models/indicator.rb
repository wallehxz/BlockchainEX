# == Schema Information
#
# Table name: indicators
#
#  id         :integer          not null, primary key
#  market_id  :integer
#  name       :string
#  created_at :datetime
#

class Indicator < ActiveRecord::Base
  belongs_to :market
  scope :recent, -> { order('created_at desc') }
  self.per_page = 10
  scope :macds, -> { where("name LIKE 'MACD%'") }

  def value
    name.split('=')[-1].to_i
  end

  def macd_m
    if name.include? 'MACD'
      name.split('=').last.split('|')[0].to_f
    end
  end

  def macd_h
    if name.include? 'MACD'
      name.split('=').last.split('|')[1].to_f
    end
  end

  after_commit :quotes_macd_reverse

  def quotes_macd_reverse
    if name.include? 'MACD'
      quotes = market.indicators.macds.last(2)
      if quotes.size > 1
        if quotes[0].macd_m > 0 && quotes[1].macd_m < 0
          market.sync_fund
          if market.fund.balance > market.regulate.retain * 0.01
            market.on_takeprofit
            market.on_stoploss
            content = "[#{Time.now.to_s(:short)}] #{market.symbols} MACD 由正转负 #{quotes[0].macd_m} => #{quotes[1].macd_m}，关闭买进操作，开启止盈止损"
            Notice.dingding(content)
          end
        end

        if quotes[0].macd_m < 0 && quotes[1].macd_m > 0
          market.step_price_bid(market.regulate.retain * 0.6)
          market.on_chasedown
          content = "[#{Time.now.to_s(:short)}] #{market.symbols} MACD 由负转正 #{quotes[0].macd_m} => #{quotes[1].macd_m}，阶梯买进，开启逐仓买进"
          Notice.dingding(content)
        end
      end
    end
  end

  after_commit :macd_m_up_trade

  def macd_m_up_trade
    if name.include?('MACD') && macd_m > 0
      quotes =  market.indicators.macds.last(10)
      macd_hs = quotes.map(&:macd_h)
      p macd_hs

      if macd_hs[-2] > 0 && macd_hs[-1] < 0 && macd_hs.size > 3
        market.sync_fund
        if market.fund.balance > market.regulate.retain * 0.01
          market.on_takeprofit if market.recent_price > market.regulate.cost
          content = "[#{Time.now.to_s(:short)}] #{market.symbols} MACD H 指标趋势下跌，#{macd_hs[-2]} => #{macd_hs[-1]} 开启价格波动扫描"
          Notice.dingding(content)
        end
      end

      macd_hs5 = macd_hs[-6..-1]
      if macd_hs5.size > 4 && macd_hs5.min == macd_hs5[-2] && macd_hs5.max < 0
        market.on_chasedown
        content = "[#{Time.now.to_s(:short)}] #{market.symbols} MACD H 指标趋势上升，#{macd_hs[-2]} => #{macd_hs[-1]} 开启追跌"
        Notice.dingding(content)
      end
    end
  end

  after_commit :macd_m_down_trade

  def macd_m_down_trade
    if name.include?('MACD') &&  macd_m < 0
      quotes =  market.indicators.macds.last(10)
      macd_ms = quotes.map(&:macd_m)
      p macd_ms
      macd_ms8 = macd_ms[-7..-1]
      if macd_ms8.size > 5 && macd_ms8.min == macd_ms8[-3] && macd_ms8.max < 0
        market.on_chasedown
        content = "[#{Time.now.to_s(:short)}] #{market.symbols} MACD M 指标趋势上升，#{macd_ms[-2]} => #{macd_ms[-1]} 开启逐仓买入"
        Notice.dingding(content)
      end

      macd_ms5 = macd_ms[-6..-1]
      if macd_ms5.max == macd_ms5[-2] && macd_ms5.size > 4
        market.sync_fund
        if market.fund.balance > market.regulate.retain * 0.1
          market.on_takeprofit if market.recent_price > market.regulate.cost
        end
        market.off_chasedown
        content = "[#{Time.now.to_s(:short)}] #{market.symbols} MACD M 指标趋势下跌，#{macd_ms[-2]} => #{macd_ms[-1]} 开启止盈"
        Notice.dingding(content)
      end
    end
  end

end
