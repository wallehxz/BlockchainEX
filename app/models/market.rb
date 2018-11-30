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
  has_many :candles
  enumerize :source, in: ['bittrex', 'binance']
  scope :seq, -> { order('sequence') }
  before_save :set_type_of_source

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
end
