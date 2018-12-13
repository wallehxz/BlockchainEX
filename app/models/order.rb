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
#

class Order < ActiveRecord::Base
  extend Enumerize
  self.per_page = 10
  scope :recent, -> { order('created_at desc') }
  enumerize :state, in: { init: 100, fail: 500, succ: 200, cancel: 0 }, default: 100, scope: true
  belongs_to :market
  after_create :fix_price
  after_save :push_order, :calc_total, :sms_order

  def calc_total
    unless self.total
      if self.price && self.amount
        self.total = (self.price * self.amount).to_d.round(4, :down)
        save
      end
    end
  end

  def fix_price
    self.price = self.price.to_d.round(8, :down)
    self.amount = self.amount.to_d.round(4, :down)
  end

  def type_cn
    { 'OrderAsk'=> '卖出', 'OrderBid'=> '买入'}[type]
  end

  def sms_order
    if state.succ?
      content = "#{market.full_name} #{type_cn}订单, 价格：#{price}, 数量: #{amount}, 小计：#{total} "
      Notice.sms(content)
    end
  end
end
