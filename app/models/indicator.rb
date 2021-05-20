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
  def quotes_reverse
    quotes = market.indicators.last(2)
    if quotes.size > 1
      if quotes[0].macd_m > 0 && quotes[1].macd_m < 0
        content = "[#{Time.now.to_s(:short)}] #{market.symbols} MACD 由正转负 #{quotes[0].macd_m} => #{quotes[1].macd_m}"
        Notice.dingding(content)
        market.on_takeprofit
      end

      if quotes[0].macd_m < 0 && quotes[1].macd_m > 0
        content = "[#{Time.now.to_s(:short)}] #{market.symbols} MACD 由负转正 #{quotes[0].macd_m} => #{quotes[1].macd_m}"
        Notice.dingding(content)
        market.step_price_bid(market.regulate.retain)
        market.on_chasedown
        market.on_fastrade
      end
    end
  end

  after_save :macd_m_up
  def macd_m_up

  end

  after_save :macd_m_down
  def macd_m_down

end
