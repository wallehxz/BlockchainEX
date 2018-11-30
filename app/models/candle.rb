# == Schema Information
#
# Table name: candles
#
#  id        :integer          not null, primary key
#  c         :float
#  h         :float
#  l         :float
#  o         :float
#  t         :float
#  v         :float
#  market_id :integer
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
end
