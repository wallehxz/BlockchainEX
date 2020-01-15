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

class Order < ActiveRecord::Base
  extend Enumerize

  self.per_page = 10
  scope :recent, -> { order('created_at desc') }
  enumerize :state, in: { init: 100, fail: 500, succ: 200, cancel: 0, rescue: 120 }, default: 100, scope: true
  enumerize :category, in: ['limit', 'market'], default: 'limit', scope: true
  belongs_to :market
  after_create :fix_price
  before_save :calc_total
  after_save :push_limit_order
  scope :succ, -> { where(state: 'succ') }
  scope :limit_order, -> { with_category(:limit) }
  scope :market_order, -> { with_category(:market) }

  def calc_total
    unless self.total
      if self.price && self.amount
        self.total = (self.price * self.amount).to_d.round(4, :down)
        save
      end
    end
  end

  def fix_price
    self.price = self.price.to_d.round(self.market&.regulate&.price_precision || 4, :down)
    self.amount = self.amount.to_d.round(self.market&.regulate&.amount_precision || 4, :down)
  end

  def type_cn
    {'OrderAsk'=> '卖出', 'OrderBid'=> '买入'}[type]
  end

  def category_cn
    {'limit'=> '限价', 'market'=> '市价'}[category]
  end

  def sms_order
    if state.succ?
      content = "#{market.symbols} #{type_cn}-#{category}订单, 价格：#{price}, 数量: #{amount}, 小计：#{total} "
      Notice.sms(content) if Rails.env.production?
      market.messages.create(body: content)
    end
  end

  def sold_tip_with(ask_order)
    content = "#{market.symbols} #{type_cn}-#{category} 出售成交, 成交数量: #{amount}，交易收益: #{(ask_order.total - total).round(2)}"
    Notice.sms(content) if Rails.env.production?
    market.messages.create(body: content)
  end

  def mock_push
    self.update_attributes(state: 200)
  end
end
