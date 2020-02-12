# == Schema Information
#
# Table name: indicators
#
#  id         :integer          not null, primary key
#  market_id  :integer
#  name       :string
#  created_at :datetime
#

class Indicator < ActiveRecord::Base
  belongs_to :market
  after_save :dingding_notice
  scope :recent, -> { order('created_at desc') }
  self.per_page = 10

  def dingding_notice
    Notice.dingding(name)
  end
end
