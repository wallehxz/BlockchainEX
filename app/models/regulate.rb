# == Schema Information
#
# Table name: regulates
#
#  id         :integer          not null, primary key
#  market_id  :integer
#  amplitude  :float
#  retain     :float
#  cost       :float
#  notify_wx  :boolean
#  notify_sms :boolean
#  notify_dd  :boolean
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  precision  :integer
#

class Regulate < ActiveRecord::Base
  validates_uniqueness_of :market_id
  belongs_to :market

  self.per_page = 10
end
