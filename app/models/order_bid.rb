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

class OrderBid < Order

  before_create :check_fund_exceed

  def push_limit_order
    if state.init?
      if Rails.env.production?
        result = market.sync_limit_order(:bid, amount, price)
        self.update_attributes(state: result['state'], cause: result['cause'])
      else
        mock_push
      end
      notice
    end
  end

  def push_market_order
    market.sync_market_order(:bid, amount)
  end

  def check_fund_exceed
    if quota = market&.regulate&.retain
      market.sync_fund
      curr_fund = market.fund.balance
      if curr_fund + amount > quota
        self.amount = quota - curr_fund
      end
    end
  end
end
