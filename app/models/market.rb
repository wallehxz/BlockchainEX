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

  has_one :regulate
  has_many :candles, dependent: :destroy
  enumerize :source, in: ['bittrex', 'binance']
  scope :seq, -> { order('sequence') }
  before_save :set_type_of_source
  after_create :extreme_report

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
    Notice.sms(content) if regulate&.notify_sms
    Notice.wechat(content) if regulate&.notify_wx
    Notice.dingding(content) if regulate&.notify_dd
  end

  def extreme_report
    if min_48 == last_quote.c
      tip = "[#{Time.now.strftime('%H:%M')}] #{full_name} 12H 最低报价 #{last_quote.c}"
      quote_notice(tip)
    elsif max_48 == last_quote.c
      tip = "[#{Time.now.strftime('%H:%M')}] #{full_name} 12H 最高报价 #{last_quote.c}"
      quote_notice(tip)
    end
  end

end
