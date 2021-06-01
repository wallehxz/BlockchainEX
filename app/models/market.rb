# == Schema Information
#
# Table name: markets
#
#  id         :integer          not null, primary key
#  base_unit  :string
#  quote_unit :string
#  sequence   :integer
#  source     :string
#  type       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
# 获取交易对相关参数限制
# https://api.binance.com/api/v1/exchangeInfo

class Market < ActiveRecord::Base
  extend Enumerize
  self.per_page = 10

  has_one :regulate, dependent: :destroy
  has_one :cash, ->(curr) { where(exchange: curr.type) }, class_name: 'Account', primary_key: 'base_unit', foreign_key: 'currency'
  has_one :fund, ->(curr) { where(exchange: curr.type) }, class_name: 'Account', primary_key: 'quote_unit', foreign_key: 'currency'
  has_many :candles, dependent: :destroy
  has_many :indicators, dependent: :destroy
  has_many :messages, dependent: :destroy
  enumerize :source, in: ['bittrex', 'binance', 'fcoin']
  scope :seq, -> { order('sequence') }
  before_save :set_type_of_source
  has_many :bids, class_name: 'OrderBid'
  has_many :asks, class_name: 'OrderAsk'

  def set_type_of_source
    self.type = self.source.capitalize if self.source
  end

  def last_quote
    candles.last
  end

  def full_name
    "#{type}[#{base_unit}-#{quote_unit}]"
  end

  def symbols
    "#{quote_unit}-#{base_unit}"
  end

  def self.market_list
    market_hash = {}
    Market.seq.map {|x| market_hash[x.symbols] = x.id }
    market_hash
  end

  def self.calc_decimal(number = 0)
    4
  end

  # Market.select(:type).distinct.map { |x| x.type.underscore.pluralize }
  def self.exchanges
    ['binance', 'ftx']
  end

  def method_missing(method, *args)
    m_string = method.to_s
    return recent_max_min('min',m_string.delete('min_')) if m_string.include?('min_')
    return recent_max_min('max',m_string.delete('max_')) if m_string.include?('max_')
    return ma_value(m_string.delete('ma_')) if m_string.include?('ma_')
    return recent_vol(m_string.delete('vol_')) if m_string.include?('vol_')
  end

  def ma_value(amount)
    candles.last(amount.to_i).map {|x| x.c }.sum / amount.to_i
  end

  def recent_max_min(side,amount)
    eval "candles.last(#{amount.to_i}).map {|x| x.c }.#{side}"
  end

  def recent_vol(amount)
    candles.last(amount.to_i).map {|x| x.v }
  end

  def rsi(amount)
    rs = smma_up(amount) / smma_down(amount)
    100 - (100 / (1 + rs))
  end

  def smma_up(amount)
    prices= candles.last(amount).map { |x| x.c }
    sum = 0
    prices.each_with_index do |price, index|
      if prices[index + 1].present? && prices[index + 1] - price > 0
        sum =+ (prices[index + 1] - price) / (amount - 1)
      end
    end
    sum
  end

  def smma_down(amount)
    prices = candles.last(amount).map { |x| x.c }
    sum = 0
    prices.each_with_index do |price, index|
      if prices[index + 1].present? && price - prices[index + 1] > 0
        sum =+ (price - prices[index + 1]) / (amount - 1)
      end
    end
    sum
  end

  def tip?
    regulate.present?
  end

  def off_trade
    regulate.update!(fast_trade: false, range_trade: false, chasedown: false)
    content = "#{symbols} 关闭所有交易策略 #{Time.now.to_s(:short)}"
    Notice.dingding(content)
  end

  def quote_notice(content)
    messages.create(body: content)
    Notice.dingding(content) if regulate&.notify_dd
  end

  def trade_notice(content)
    messages.create(body: content)
    Notice.sms(content) if regulate&.notify_sms
    Notice.dingding(content) if regulate&.notify_dd
  end

  def extreme_report
    if min_48 == last_quote.c
      tip = "[#{Time.now.strftime('%H:%M')}] #{full_name} DOWN Price #{last_quote.c} Vol #{last_quote.v}"
      quote_notice(tip)
      if regulate&.range_trade
        _amount = regulate.range_cash
        _profit = regulate.range_profit || 0.0025
        _price = recent_price * (1 - _profit)
        new_bid(_price,_amount)
      end
    elsif max_48 == last_quote.c
      tip = "[#{Time.now.strftime('%H:%M')}] #{full_name} UP Price #{last_quote.c} Vol #{last_quote.v}"
      quote_notice(tip)
      if regulate&.range_trade
        _amount = regulate.range_cash
        _profit = regulate.range_profit || 0.003
        _price = recent_price * (1 + _profit)
        new_ask(_price,_amount)
      end
      if fund.balance > regulate.retain * 0.1
        if last_quote.c > avg_cost + regulate.cash_profit
          regulate.update!(support: last_quote.c * 0.9975)
          regulate.update!(takeprofit: true) unless regulate.takeprofit
          content = "#{Time.now.to_s(:short)} #{symbols} 止盈价格更新为 #{regulate.support}"
          Notice.dingding(content)
        end
      end
    end
  end

  def volume_report
    if vol_96.max == last_quote.v
      kline = last_quote.kline_info
      tip = "[#{Time.now.strftime('%H:%M')}] #{full_name} 8H MaxVols #{last_quote.v} Price #{last_quote.c}，Float #{kline}"
      quote_notice(tip)

      if regulate&.range_trade && kline[1] > 0
        _amount = regulate.range_cash
        new_bid(recent_price * 0.9975,_amount)
      end
    end
  end

  def latest_bid
    bids.succ.recent.first
  end

  def latest_ask
    asks.succ.recent.first
  end

  def new_bid(price, amount, category = 'limit')
    bids.create(price: price, amount: amount, category: category)
  end

  def new_ask(price, amount, category = 'limit')
    asks.create(price: price, amount: amount, category: category)
  end

  def greedy?
    intor = indicators&.last&.macd_m || 0
    if intor > 0
      true
    else
      false
    end
  end

  def on_fastrade
    regulate.update!(fast_trade: true)
    Daemon.start('fastrade')
  end

  def off_fastrade
    regulate.update!(fast_trade: false)
  end

  def on_chasedown
    regulate.update!(chasedown: true)
    Daemon.start('chasedown')
  end

  def off_chasedown
    regulate.update!(chasedown: false)
  end

  def on_stoploss
    regulate.update!(stoploss: true)
    Daemon.start('stoploss')
  end

  def off_stoploss
    regulate.update!(stoploss: false)
  end

  def on_takeprofit
    regulate.update!(takeprofit: true)
    Daemon.start('takeprofit')
  end

  def off_takeprofit
    regulate.update!(takeprofit: false)
  end

  def on_rangetrade
    regulate.update!(range_trade: true)

  end

  def off_rangetrade
    regulate.update!(range_trade: false)
  end

  def off_bids
    off_rangetrade
    off_chasedown
  end

end
