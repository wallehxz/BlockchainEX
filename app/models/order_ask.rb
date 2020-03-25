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

  before_validation :check_amount_exceed

  def push_limit_order
    if state.init?
      if Rails.env.production?
        result = market.sync_limit_order(:ask, amount, price)
        self.update_attributes(state: result['state'], cause: result['cause'])
      else
        mock_push
      end
      sms_order
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

end
