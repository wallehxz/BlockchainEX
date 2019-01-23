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
  scope :recent, -> { order(t: :desc) }

  after_create :calc_ts

  self.per_page = 15

  def ms_t
    t.to_i * 1000
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
end
