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
  after_save :market_buy_or_sell
  scope :recent, -> { order('created_at desc') }
  self.per_page = 10

  def market_buy_or_sell
    if name.include? 'buy'
      amount = market.regulate&.retain || 0
      market.sync_fund
      fund = market.fund&.balance || 0
      if amount > 0 && fund < amount * 1.5
        market.step_price_bid(amount)
      end
    elsif name.include? 'sell'
      amount = market.regulate&.retain || 0
      market.sync_fund
      fund = market.fund&.balance || 0
      if fund > 0 && amount > 0
        amount = fund > amount ? amount : fund
        market.step_price_ask(amount)
      end
    end
  end
end
