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
  after_save :fix_price_amount
  after_save :push_limit_order
  scope :succ, -> { where(state: 'succ') }
  scope :limit_order, -> { with_category(:limit) }
  scope :market_order, -> { with_category(:market) }

  def fix_price_amount
    if total.nil? || total != (price * amount).to_d.round(4, :down).to_f
      self.price = price.to_d.round(market&.regulate&.price_precision || 4, :down)
      self.amount = amount.to_d.round(market&.regulate&.amount_precision || 4, :down)
      self.total = (price * amount).to_d.round(4, :down)
      save
    end
  end

  def type_cn
    {'OrderAsk'=> '卖出', 'OrderBid'=> '买入'}[type]
  end

  def category_cn
    {'limit'=> '限价', 'market'=> '市价', 'chives'=> '韭菜价' }[category]
  end

  def notice
    if state.succ?
      sms_notice if market.regulate.notify_sms
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

  def sms_notice
    if Time.now.hour.in? [*9..22]
      content = "\n> #{market.symbols} #{type_cn}订单\n" +
      "> 价格：#{price} #{market.base_unit}\n" +
      "> 数量：#{amount} #{market.quote_unit}\n" +
      "> 成交额 #{total.round(2)} #{market.base_unit}\n"
      Notice.sms(content)
    # end
  end

  def mock_push
    self.update_attributes(state: 200)
  end
end
