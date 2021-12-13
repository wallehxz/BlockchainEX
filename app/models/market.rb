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
  enumerize :source, in: ['future', 'binance']
  scope :seq, -> { order('sequence') }
  before_save :set_type_of_source
  has_many :bids, class_name: 'OrderBid'
  has_many :asks, class_name: 'OrderAsk'

  def get_price
    t = get_ticker('1m',1)[0]
    { last: t[4].to_f, ask: t[2].to_f, bid: t[3].to_f }
  end

  def generate_quote
    t = latest_ticker('5m',150)
    ticker = {}
    ticker[:o] = t[1]
    ticker[:h] = t[2]
    ticker[:l] = t[3]
    ticker[:c] = t[4]
    ticker[:v] = t[5]
    ticker[:t] = (t[0] / 1000) + 300
    ticker
    candles.create(ticker)
  end

  def latest_ticker(interval,timeout)
    current= Time.now.to_i
    t = get_ticker(interval,2)
    t_1 = t[1][0] / 1000
    return t[1] if current - t_1 > timeout
    t[0]
  end

  def batch_sync_quote
    if candles.count < 10
      batch_quote(300) rescue nil
    end
  end

  def batch_quote(amount = 100)
    t_100 = get_ticker('5m',amount)
    t_100.each do |t|
      ticker = {}
      ticker[:o] = t[1]
      ticker[:h] = t[2]
      ticker[:l] = t[3]
      ticker[:c] = t[4]
      ticker[:v] = t[5]
      ticker[:t] = (t[0] / 1000) + 300
      ticker
      candles.create(ticker)
    end
  end

  def set_type_of_source
    self.type = self.source.capitalize if self.source
  end

  def last_quote
    candles.last
  end

  def full_name
    "【#{quote_unit}-#{base_unit}】#{type}"
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
    ['binance', 'future']
  end

  def recent_vol(amount)
    candles.last(amount.to_i).map {|x| x.v }
  end

  def off_trade
    regulate.update!(range_trade: false, chasedown: false)
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

  def method_missing(method, *args)
    m_string = method.to_s
    return recent_max_min('min',m_string.delete('min_')) if m_string.include?('min_')
    return recent_max_min('max',m_string.delete('max_')) if m_string.include?('max_')
    return recent_vol(m_string.delete('vol_')) if m_string.include?('vol_')
  end

  def recent_max_min(side,amount)
    eval "candles.last(#{amount.to_i}).map {|x| x.c }.#{side}"
  end

  def recent_vol(amount)
    candles.last(amount.to_i).map {|x| x.v }
  end

  def extreme_report
    if min_48 == last_quote.c
      tip = "[#{Time.now.strftime('%H:%M')}] #{full_name} 4H DOWN Price #{last_quote.c} Vol #{last_quote.v}"
      quote_notice(tip)
      #行情下跌 先开空 后再收益平空
      if source == 'future'
        if regulate.range_trade
          price  = get_book[:ask]
          amount = regulate.fast_cash
          new_kai_short(price, amount)
        end
        profit = regulate.range_profit
        short = short_position
        if short['unrealizedProfit'].to_f > profit
          new_ping_short(last_quote.c, short['positionAmt'].to_f.abs)
        end
      end
    end

    if max_48 == last_quote.c
      tip = "[#{Time.now.strftime('%H:%M')}] #{full_name} 4H UP Price #{last_quote.c} Vol #{last_quote.v}"
      quote_notice(tip)
      # 行情上涨 先开多 后再收益平多
      if source == 'future'
        if regulate.range_trade
          price  = get_book[:bid]
          amount = regulate.fast_cash
          new_kai_long(price, amount)
        end
        profit = regulate.range_profit
        long = long_position
        if long['unrealizedProfit'].to_f > profit
          new_ping_long(last_quote.c, long['positionAmt'].to_f.abs)
        end
      end
    end
  end

  def volume_report
    if vol_96.max == last_quote.v
      kline = last_quote.kline_info
      tip = "[#{Time.now.strftime('%H:%M')}] #{full_name} 8H MaxVols #{last_quote.v} Price #{last_quote.c}，Float #{kline}"
      quote_notice(tip)
    end
  end

  def latest_bid
    bids.succ.recent.first
  end

  def latest_ask
    asks.succ.recent.first
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

  def off_asks
    off_takeprofit
    off_stoploss
  end

end
