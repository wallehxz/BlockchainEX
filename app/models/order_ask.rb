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
#

class OrderAsk < Order

  def push_limit_order
    if state.init? && category.limit?
      if Rails.env.production?
        result = market.sync_limit_order(:ask, amount, price)
        self.update_attributes(state: result['state'], cause: result['cause'])
      else
        mock_push
      end
      notice
    end
  end

  def push_market_order
    market.sync_market_order(:ask, amount)
  end

  after_create :push_step_order
  def push_step_order
    if state.init? && category.step?
      self.errors.add(:cause, '重置阶梯订单')
      market.step_price_ask(amount)
    end
  end

  before_create :check_amount_exceed
  def check_amount_exceed
    market.sync_fund
    curr_fund = market.fund.balance
    if amount > curr_fund
      self.amount = curr_fund
    end
  end

  before_create :check_legal_profit
  def check_legal_profit
    if category == 'limit'
      average = market.avg_cost
      if price < average
        self.state = 500
        self.cause = "Limit ask price must > cost #{average}"
      end
    end
  end

end
