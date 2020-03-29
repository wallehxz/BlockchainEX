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

  before_validation :check_legal_profit
  before_validation :check_amount_exceed

  def push_limit_order
    if state.init?
      if Rails.env.production?
        result = market.sync_limit_order(:ask, amount, price)
        self.update_attributes(state: result['state'], cause: result['cause'])
      else
        mock_push
      end
      notice_order
    end
  end

  def push_market_order
    market.sync_market_order(:ask, amount)
  end

  def check_amount_exceed
    market.sync_fund
    curr_fund = market.fund.balance
    if amount > curr_fund
      self.amount = curr_fund
    end
    if curr_fund == 0
      self.state = 500
      self.cause = "#{market.quote_unit} Insufficient balance"
    end
  end

  def check_legal_profit
    if ['limit', 'market'].include? category
      bid_order = market.bids.succ.order(price: :asc).first
      if bid_order
        cash_profit = market.regulate&.cash_profit || bid_order.price * 0.01
        price_profit = cash_profit + bid_order.price
        if price < price_profit
          self.state = 500
          self.cause = "Ask price must more than #{price_profit}"
        end
      else
        self.state = 500
        self.cause = "No legal bid order match"
      end
    end
  end

end
