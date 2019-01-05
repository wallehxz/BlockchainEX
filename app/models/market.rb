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
#

class Market < ActiveRecord::Base
  extend Enumerize
  self.per_page = 10

  has_one :regulate, dependent: :destroy
  has_one :cash, ->(curr) { where(exchange: curr.type) }, class_name: 'Account', primary_key: 'base_unit', foreign_key: 'currency'
  has_one :fund, ->(curr) { where(exchange: curr.type) }, class_name: 'Account', primary_key: 'quote_unit', foreign_key: 'currency'
  has_many :candles, dependent: :destroy
  enumerize :source, in: ['bittrex', 'binance']
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
    "#{base_unit}-#{quote_unit}"
  end

  def self.market_list
    market_hash = {}
    Market.seq.map {|x| market_hash[x.symbols] = x.id }
    market_hash
  end

  def self.calc_decimal(number = 0)
    if number < 0.0001
      return 6
    elsif number < 0.01
      return 4
    elsif number > 100
      return 1
    end
    2
  end

  # Market.select(:type).distinct.map { |x| x.type.underscore.pluralize }
  def self.exchanges
    ['bittrex', 'binance']
  end

  def method_missing(method, *args)
    m_string = method.to_s
    return recent_max_min('min',m_string.delete('min_')) if m_string.include?('min_')
    return recent_max_min('max',m_string.delete('max_')) if m_string.include?('max_')
    return ma_value(m_string.delete('ma_')) if m_string.include?('ma_')
  end

  def ma_value(amount)
    candles.last(amount.to_i).map {|x| x.c }.sum / amount.to_i
  end

  def recent_max_min(side,amount)
    eval "candles.last(#{amount.to_i}).map {|x| x.c }.#{side}"
  end

  def tip?
    regulate.present?
  end

  def quote_notice(content)
    Notice.wechat(content) if regulate&.notify_wx
    Notice.dingding(content) if regulate&.notify_dd
  end

  def trade_notice(content)
    Notice.sms(content) if regulate&.notify_sms
  end

  def extreme_report
    if min_192 == last_quote.c
      tip = "[#{Time.now.strftime('%H:%M')}] #{full_name} 48H 最低报价 #{last_quote.c}"
      quote_notice(tip)
      trade_notice(tip)
      is_shopping
      amplitude = 1 - (max_192 / min_192).to_f.round(2)
      regulate.update(amplitude: amplitude) if regulate
    elsif max_192 == last_quote.c
      tip = "[#{Time.now.strftime('%H:%M')}] #{full_name} 48H 最高报价 #{last_quote.c}"
      trade_notice(tip)
      quote_notice(tip)
      amplitude = (max_192 / min_192).to_f.round(2) - 1
      regulate.update(amplitude: amplitude) if regulate
    end
  end

  def latest_bid
    bids.succ.recent.first
  end

  def latest_ask
    asks.succ.recent.first
  end

  def is_shopping
    if regulate&.cost > 0
      if !latest_bid || Time.now - latest_bid&.created_at > 12.hour
        sync_cash
        if cash.balance > regulate&.cost
          shopping
        end
      end
    end
    false
  end

  def shopping
    total = cash.balance > regulate.cost ? regulate.cost : cash.balance
    price = last_quote.c
    amount = (total * 0.995 / price).to_d.round(4,:down)
    new_bid(price, amount)
  end

  def new_bid(price, amount)
    bids.create(price: price, amount: amount)
  end

  def new_ask(price, amount)
    asks.create(price: price, amount: amount)
  end
end
