# == Schema Information
#
# Table name: orders
#
#  id         :integer          not null, primary key
#  market_id  :integer
#  type       :string
#  price      :float
#  amount     :float
#  total      :float
#  state      :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  cause      :string
#  category   :string           default("limit")
#  position   :string
#

class OrderAsk < Order
  validates_presence_of :price, :amount

  after_create :push_step_order
  def push_step_order
    if state.init? && category.step? && market.source == 'binance'
      market.step_price_ask(amount)
    end
  end

  before_create :check_amount_exceed
  def check_amount_exceed
    if market.source == 'binance'
      market.sync_fund
      curr_fund = market.fund.balance
      if amount > curr_fund
        self.amount = curr_fund
      end
    end
  end

  before_create :check_legal_profit
  def check_legal_profit
    if category == 'limit' && market.source == 'binance'
      average = market.avg_cost
      if price < average
        return false
      end
    end
  end

  after_save :fine_tuning_precision
  def fine_tuning_precision
    if category == 'market' && state == 'fail' && market.source == 'binance'
      cur_precision = amount.to_s.split('.')[1].size rescue 0
      if cur_precision > 1
        content = "#{market.symbols} 市价卖出订单数量 #{amount} 精度降维"
        Notice.dingding(content)
        new_amount = amount.to_d.round(cur_precision - 1, :down).to_f
        market.market_price_ask(new_amount)
      end
    end
  end

  before_create :check_short_fund_exceed
  def check_short_fund_exceed
    quota = market&.regulate&.retain
    if quota && position == 'SHORT'
      total_fund = market.short_amount rescue 0
      if total_fund >= quota
        return false
      end
      if quota > total_fund && quota < total_fund + amount
        self.amount = quota - total_fund
      end
    end
  end

end
