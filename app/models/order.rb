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

class Order < ActiveRecord::Base
  extend Enumerize
  validates_presence_of :price, :amount
  self.per_page = 10
  scope :recent, -> { order('created_at desc') }
  enumerize :state, in: { init: 100, fail: 500, succ: 200, cancel: 0, rescue: 120 }, default: 100, scope: true
  enumerize :category, in: ['limit', 'market', 'step'], default: 'limit', scope: true
  enumerize :position, in: ['LONG', 'SHORT']
  belongs_to :market
  has_one :regulate, primary_key: 'market_id', foreign_key: 'market_id'
  after_save :fix_price_amount
  after_save :push_limit_order
  after_save :push_market_order
  after_save :push_future_step_order
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
    {'limit'=> '限价', 'market'=> '市价', 'step'=> '阶梯价' }[category]
  end

  def position_cn
    {'LONG'=> '做多', 'SHORT'=> '做空'}[position]
  end

  def market_cn
    if market.source == 'binance'
      '现货'
    elsif market.source == 'future'
      '合约'
    end
  end

  def order_cn
    if position.blank?
      {'OrderAsk'=> '卖出', 'OrderBid'=> '买入'}[type]
    elsif position == 'SHORT'
      {'OrderAsk'=> '开空', 'OrderBid'=> '平空'}[type]
    elsif position == 'LONG'
      {'OrderAsk'=> '平多', 'OrderBid'=> '开多'}[type]
    end
  end

  def notice
    if state.succ?
      regulate.update_avg_cost if type == 'OrderBid' && market.source == 'binance'
      sms_notice if market.regulate.notify_sms
      push_url = "https://oapi.dingtalk.com/robot/send?access_token=#{Setting.trading_bot}"
      body_params ={ msgtype:'markdown', markdown:{ title: "#{market_cn}订单" } }
      body_params[:markdown][:text] =
        "## #{order_cn} #{category_cn} 订单\n\n" +
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
      content = "\n>#{order_cn} #{category_cn} 订单\n" +
      "> 价格：#{price} #{market.base_unit}\n" +
      "> 数量：#{amount} #{market.quote_unit}\n" +
      "> 成交额 #{total.round(2)} #{market.base_unit}\n"
      Notice.sms(content)
    end
  end

  def failed_notice
    if state.fail?
      push_url = "https://oapi.dingtalk.com/robot/send?access_token=#{Setting.trading_bot}"
      body_params ={ msgtype:'markdown', markdown:{ title: "#{type_cn} 订单" } }
      body_params[:markdown][:text] =
        "#### #{position_cn} #{category_cn} #{type_cn} 失效订单\n\n" +
        "> 价格：#{price} #{market.base_unit}\n\n" +
        "> 数量：#{amount} #{market.quote_unit}\n\n" +
        "> 时间：#{updated_at.to_s(:short)}\n\n" +
        "> 失败原因：#{cause}\n"
      res = Faraday.post do |req|
        req.url push_url
        req.headers['Content-Type'] = 'application/json'
        req.body = body_params.to_json
      end
    end
  end

  after_save :zero_cancel
  def zero_cancel
    if amount == 0 && state != 0
      self.state = 0
      save
    end
  end

  def mock_push
    if state.init?
      self.update_attributes(state: 200)
    end
  end

  def push_limit_order
    if state.init? && category.limit?
      if Rails.env.production?
        result = market.sync_limit_order(self)
        self.update_attributes(state: result['state'], cause: result['cause'])
        notice
      else
        mock_push
      end
    end
  end

  def push_market_order
    if state.init? && category.market?
      if Rails.env.production?
        result = market.sync_market_order(self)
        self.update_attributes(state: result['state'], cause: result['cause'])
        notice
      else
        mock_push
      end
    end
  end

  def push_future_step_order
    if state.init? && category.step? && market.source == 'future'
      amount_l = market.long_position['positionAmt'].to_f
      amount_s = market.short_position['positionAmt'].to_f.abs
      result = market.step_limit_order(self)

      if position == 'LONG'
        amount_lo = market.long_position['positionAmt'].to_f
        if amount_lo != amount_l
          self.update_attributes(state: 200)
          notice
        else
          self.update_attributes(state: 0)
        end
      end

      if position == 'SHORT'
        amount_so = market.short_position['positionAmt'].to_f.abs
        if amount_so != amount_s
          self.update_attributes(state: 200)
          notice
        else
          self.update_attributes(state: 0)
        end
      end
    end
  end

end
