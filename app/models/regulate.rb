# == Schema Information
#
# Table name: regulates
#
#  id               :integer          not null, primary key
#  market_id        :integer
#  amplitude        :float
#  retain           :float
#  cost             :float
#  notify_wx        :boolean
#  notify_sms       :boolean
#  notify_dd        :boolean
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  fast_profit      :float
#  fast_trade       :boolean          default(FALSE)
#  support          :float
#  resistance       :float
#  fast_cash        :float
#  range_trade      :boolean          default(FALSE)
#  range_cash       :float
#  range_profit     :float
#  amount_precision :integer
#  price_precision  :integer
#  cash_profit      :float
#  stoploss         :boolean          default(FALSE)
#  takeprofit       :boolean          default(FALSE)
#  chasedown        :boolean          default(FALSE)
#

class Regulate < ActiveRecord::Base
  validates_uniqueness_of :market_id
  belongs_to :market

  self.per_page = 10

  def update_avg_cost
    if market.source == 'binance'
      average = market.avg_cost
      if average > 0
        new_average = average.to_d.round(price_precision, :down)
        self.resistance = new_average + range_profit
        self.cost = new_average
        save
        content = "[#{Time.now.to_s(:short)}] #{market.symbols} Cost: #{new_average} \nProfit： #{resistance}"
        Notice.dingding(content)
      end
    end
  end

  def current_fund
    market.sync_fund if market.source == 'binance'
  end

  after_save :turnover

  def turnover
    if (stoploss || takeprofit) && chasedown && market.source == 'binance'
      self.toggle!(:chasedown)
      content = "[#{Time.now.to_s(:short)}] #{market.symbols} 止损卖出和逐仓买入不可同时执行，关闭追跌"
      Notice.dingding(content)
    end
  end

  after_create :update_price_amount_precision
  def update_price_amount_precision
    if market.source == 'binance'
      ticker = market.ticker
      self.amount_precision = ticker['bidQty'].to_f.to_s.split('.').last.size
      self.price_precision  = ticker['bidPrice'].to_f.to_s.split('.').last.size
      save
    end

    if market.source == 'future'
      ticker = market.ticker
      self.amount_precision = ticker['lastQty'].to_f.to_s.split('.').last.size
      self.price_precision  = ticker['lastPrice'].to_f.to_s.split('.').last.size
      save
    end
  end

end
