# == Schema Information
#
# Table name: candles
#
#  id        :integer          not null, primary key
#  market_id :integer
#  o         :float
#  h         :float
#  l         :float
#  c         :float
#  v         :float
#  t         :string
#  ts        :datetime
#

class Candle < ActiveRecord::Base
  belongs_to :market
  scope :recent, -> { order(t: :desc) }
  scope :history, -> { order(:ts) }
  after_create :calc_ts, :update_resistance_level, :update_support_level

  self.per_page = 15

  def ms_t
    t.to_i * 1000
  end

  def kline_info
    if self.c > self.o
      [(self.h - self.c).round(4),(self.c - self.o).round(4),(self.o - self.l).round(4)]
    else
      [(self.h - self.o).round(4),(self.c - self.o).round(4),(self.c - self.l).round(4)]
    end
  end

  def int_t
    t.to_i
  end

  def calc_ts
    self.ts = Time.at self.t.to_i
    save
  end

  def short_date
    Time.at(int_t).to_s(:short)
  end

  def update_support_level
    if market.regulate && market.min_96 == self.c
      market.regulate.update(support: market.min_96)
    end
  end

  def update_resistance_level
    if market.regulate && market.max_96 == self.c
      market.regulate.update(resistance: market.max_96)
    end
  end

  def index(amount = 48)
    candles_24h = market.candles.where("ts <= ?", ts).last(amount)
    candles_body = candles_24h.map(&:kline_info)
    up_body = candles_body.select { |x| x[1] > 0 }.size
    down_body = candles_body.select { |x| x[1] < 0 }.size
    first_price = candles_24h.first.c
    last_price = candles_24h.last.c
    (up_body.to_f / candles_24h.size) * (last_price.to_f / first_price)
  end

end
