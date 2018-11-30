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
  self.per_page = 15

  def ms_t
    t.to_i * 1000
  end

  def int_t
    t.to_i
  end
end
