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
#

class Order < ActiveRecord::Base
  extend Enumerize
  self.per_page = 10
  scope :recent, -> { order('created_at desc') }
  enumerize :state, in: { init: 100, fail: 500, succ: 200, cancel: 0, rescue: 120 }, default: 100, scope: true
  belongs_to :market
  after_create :fix_price
  after_save :calc_total, :sms_order
  after_save :push_order
  scope :succ, -> { where(state: 'succ') }

  def calc_total
    unless self.total
      if self.price && self.amount
        self.total = (self.price * self.amount).to_d.round(4, :down)
        save
      end
    end
  end

  def fix_price
    self.price = self.price.to_d.round(6, :down)
    self.amount = self.amount.to_d.round(self.market&.regulate&.precision || 4, :down)
  end

  def type_cn
    {'OrderAsk'=> '卖出', 'OrderBid'=> '买入'}[type]
  end

  def sms_order
    if state.succ?
      content = "#{market.symbols} #{type_cn}订单, 价格：#{price}, 数量: #{amount}, 小计：#{total} "
      Notice.sms(content)
      market.messages.create(body: content)
    end
  end
end
