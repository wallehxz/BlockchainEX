# == Schema Information
#
# Table name: regulates
#
#  id               :integer          not null, primary key
#  market_id        :integer
#  amplitude        :float
#  retain           :float
#  cost             :float
#  cash_profit      :float
#  notify_wx        :boolean
#  notify_sms       :boolean
#  notify_dd        :boolean
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  fast_trade       :boolean          default(FALSE)
#  fast_cash        :float
#  fast_profit      :float
#  support          :float
#  resistance       :float
#  range_trade      :boolean          default(FALSE)
#  range_cash       :float
#  range_profit     :float
#  amount_precision :integer
#  price_precision  :integer
#

class Regulate < ActiveRecord::Base
  validates_uniqueness_of :market_id
  belongs_to :market

  self.per_page = 10

  def take_profit_cost
    average = market.avg_cost
    if average > 0
      new_average = average.to_d.round(price_precision, :down)
      self.resistance = new_average + cash_profit
      self.support = new_average - cash_profit
      save
      content = "[#{Time.now.to_s(:short)}] #{market.symbols} Cost: #{new_average} \nProfit： #{resistance} \nLoss： #{support}"
      Notice.dingding(content)
    end
  end
end
