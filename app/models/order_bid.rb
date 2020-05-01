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
  after_save :preset_loss

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
      if curr_fund > quota
        self.state = 500
        self.cause = "Quota has fulled"
      end
      if curr_fund < quota && curr_fund + amount > quota
        self.amount = quota - curr_fund
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

  def preset_loss
    succ_orders = market.bids.succ
    if succ_orders.count > 0 && state == 'succ'
      ave_price = succ_orders.map(&:price).sum / succ_orders.count
      support = ave_price * (1 - 0.00618)
      support_price = market&.regulate&.support
      if support < support_price
        market&.regulate.update(support: support)
        Notice.dingding("[#{Time.now.to_s(:short)}] \n 止损价更新为：#{support}")
      end
    end
  end
end
