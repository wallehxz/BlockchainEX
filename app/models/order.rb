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
  validates_presence_of :price, :amount
  self.per_page = 10
  scope :recent, -> { order('created_at desc') }
  enumerize :state, in: { init: 100, fail: 500, succ: 200, cancel: 0, rescue: 120 }, default: 100, scope: true
  enumerize :category, in: ['limit', 'market', 'chives'], default: 'limit', scope: true
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
    {'limit'=> '限价', 'market'=> '市价', 'chives'=> '韭菜价' }[category]
  end

  def notice
    if state.succ?
      push_url = "https://oapi.dingtalk.com/robot/send?access_token=#{Settings.trading_bot}"
      body_params ={ msgtype:'markdown', markdown:{ title: "#{type_cn}订单" } }
      body_params[:markdown][:text] =
        "#### #{market.type} #{type_cn}订单\n\n" +
        "> 时间：#{updated_at.to_s(:short)}\n\n" +
        "> 价格：#{price} #{market.base_unit}\n\n" +
        "> 数量：#{amount} #{market.quote_unit}\n\n" +
        "> 成交额 #{total.round(4)} #{market.base_unit}\n\n" +
        "> ![screenshot](https://source.unsplash.com/random/400x200)\n"
      res = Faraday.post do |req|
        req.url push_url
        req.headers['Content-Type'] = 'application/json'
        req.body = body_params.to_json
      end
    end
  end

  def mock_push
    self.update_attributes(state: 200)
  end
end
