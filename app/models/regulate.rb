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
#

class Regulate < ActiveRecord::Base
  belongs_to :market

  self.per_page = 10


end
