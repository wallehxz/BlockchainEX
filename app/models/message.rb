# == Schema Information
#
# Table name: messages
#
#  id         :integer          not null, primary key
#  market_id  :integer
#  body       :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class Message < ActiveRecord::Base
  belongs_to :market
  scope :recent, -> { order('created_at desc') }
  self.per_page = 10

  def short_date
    created_at.to_s(:short)
  end
end
