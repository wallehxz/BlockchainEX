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
    if market.regulate
      cls = market.candles.last(3)
      if market.candles.size > 48 && market.min_48 == cls[1].c
        if cls[1].c < cls[0].c && cls[1].c < cls[2].o
          market.regulate.update(support: cls[1].c)
        end
      end
    end
  end

  def update_resistance_level
    if market.regulate
      cls = market.candles.last(3)
      if market.candles.size > 48 && market.max_48 == cls[1].c
        if cls[1].c > cls[0].c && cls[1].c > cls[2].o
          market.regulate.update(resistance: cls[1].c)
        end
      end
    end
  end
end
