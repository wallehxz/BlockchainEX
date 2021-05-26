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

  after_save :quotes_macd_reverse

  def quotes_macd_reverse
    quotes = market.indicators.last(2)
    if quotes.size > 1
      if quotes[0].macd_m > 0 && quotes[1].macd_m < 0
        market.off_bids
        market.on_takeprofit
        market.on_stoploss
        content = "[#{Time.now.to_s(:short)}] #{market.symbols} MACD 由正转负 #{quotes[0].macd_m} => #{quotes[1].macd_m}，关闭买进操作，开启止盈止损"
        Notice.dingding(content)
      end

      if quotes[0].macd_m < 0 && quotes[1].macd_m > 0
        market.step_price_bid(market.regulate.retain * 0.6)
        market.on_chasedown
        content = "[#{Time.now.to_s(:short)}] #{market.symbols} MACD 由负转正 #{quotes[0].macd_m} => #{quotes[1].macd_m}，阶梯买进，开启回落买进"
        Notice.dingding(content)
      end
    end
  end

  after_save :macd_up_trade
  def macd_up_trade
    if macd_m > 0
      quotes =  market.indicators.last(10)
      macd_hs = quotes.map(&:macd_h)
      if macd_hs[-2] > 0 && macd_hs[-1] < 0
        market.sync_fund
        market.on_fastrade if market.fund.balance > market.regulate.retain * 0.1
        content = "[#{Time.now.to_s(:short)}] #{market.symbols} MACD H 指标改变趋势，#{macd_hs[-2]} => #{macd_hs[-1]} 开启价格波动扫描"
        Notice.dingding(content)
      end
      macd_hs5 = macd_hs[-5..-1]
      if macd_hs5.min == macd_hs5[-2] && macd_hs5[-2] < 0
        market.on_chasedown
        market.on_fastrade
        content = "[#{Time.now.to_s(:short)}] #{market.symbols} MACD H 指标改变趋势，#{macd_hs[-2]} => #{macd_hs[-1]} 开启追跌"
        Notice.dingding(content)
      end
    end
  end

end
