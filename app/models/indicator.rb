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
  scope :recent, -> { order('created_at desc') }
  self.per_page = 10

  def value
    name.split('=')[-1].to_i
  end

  after_save :quotes_reverse
  def quotes_reverse
    quotes = market.indicators.last(2)
    if quotes.size > 1
      if quotes[0].value > 0 && quotes[1].value < 0
        content = "[#{Time.now.to_s(:short)}] #{market.symbols} 行情指数由正转负 #{quotes[0].value} => #{quotes[1].value}"
        Notice.dingding(content)
      end

      if quotes[0].value < 0 && quotes[1].value > 0
        content = "[#{Time.now.to_s(:short)}] #{market.symbols} 行情指数由负转正 #{quotes[0].value} => #{quotes[1].value}"
        Notice.dingding(content)
      end
    end
  end

end
