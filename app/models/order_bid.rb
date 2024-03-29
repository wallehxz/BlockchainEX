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

class OrderBid < Order
  validates_presence_of :price, :amount

  after_create :push_step_order
  def push_step_order
    if state.init? && category.step? && market.source == 'binance'
      market.step_price_bid(amount)
    end
  end

  before_create :check_fund_exceed
  def check_fund_exceed
    quota = market&.regulate&.retain
    if quota && market.source == 'binance'
      total_fund = market.all_funds rescue 0
      if quota - total_fund < 0.01
        self.errors.add(:amount, '持仓数量超标')
      elsif total_fund + amount > quota
        self.amount = quota - total_fund
      end
    end
  end

  before_create :check_long_fund_exceed
  def check_long_fund_exceed
    quota = market&.regulate&.retain
    if quota && position =='LONG'
      total_fund = market.long_amount rescue 0
      if total_fund >= quota
        return false
      end
      if quota > total_fund && quota < total_fund + amount
        self.amount = quota - total_fund
      end
    end
  end

  before_create :check_insufficient_cash
  def check_insufficient_cash
    if market.source == 'binance'
      market.sync_cash
      cash = market.cash.balance
      if amount * price > cash
        self.amount = cash / price
      end
    end
  end

end
