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
  before_create :check_support_price

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
      total_fund = market.all_funds rescue 0
      if quota - total_fund < 0.01
        self.state = 500
        self.cause = "Quota has fulled"
      elsif total_fund + amount > quota
        self.amount = quota - total_fund
      end
    end
  end

  def check_support_price
    if support_price = market&.regulate&.support
      if price < support_price
        self.state = 500
        self.cause = "Bid price more than #{support_price}"
      end
    end
  end

end
