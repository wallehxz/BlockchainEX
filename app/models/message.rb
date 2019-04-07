class Message < ActiveRecord::Base
  belongs_to :market

  def short_date
    created_at.to_s(:short)
  end
end
