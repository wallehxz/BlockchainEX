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
  after_save :step_buy_or_sell
  scope :recent, -> { order('created_at desc') }
  self.per_page = 10

  def step_buy_or_sell
    if name.include? 'step_buy'
      retain = market.regulate&.retain || 0
      market.sync_fund
      fund = market.fund&.balance || 0
      if retain > 0 && fund < retain * 0.1
        amount = retain - fund
        market.step_price_bid(amount)
      end
    elsif name.include? 'step_sell'
      retain = market.regulate&.retain || 0
      market.sync_fund
      fund = market.fund&.balance || 0
      last_orders = market.bid_filled_orders.last(10)
      bid_price = last_orders.map { |x| x['price'].to_f }.sum / last_orders.size
      recent_price = market.recent_price
      if fund > retain * 0.1 && retain > 0
        amount = fund > amount ? amount : fund
        if recent_price > bid_price
          market.step_price_ask(amount)
        elsif recent_price < bid_price
          market.market_price_ask(amount)
        end
      end
    end
  end

end
