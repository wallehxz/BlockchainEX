# == Schema Information
#
# Table name: regulates
#
#  id          :integer          not null, primary key
#  market_id   :integer
#  amplitude   :float
#  retain      :float
#  cost        :float
#  notify_wx   :boolean
#  notify_sms  :boolean
#  notify_dd   :boolean
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  precision   :integer
#  fast_profit :float
#  fast_trade  :boolean          default(FALSE)
#  support     :float
#  resistance  :float
#  fast_cash   :float
#

class Regulate < ActiveRecord::Base
  validates_uniqueness_of :market_id
  belongs_to :market

  self.per_page = 10
end
