# == Schema Information
#
# Table name: markets
#
#  id         :integer          not null, primary key
#  sequence   :integer
#  base_unit  :string
#  quote_unit :string
#  source     :string
#  type       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

# https://developer.fcoin.com/zh.html
class Fcoin < Market
  INTERVAL = {'1m'=> 'M1', '3m'=> 'M3', '5m'=> 'M5', '15m'=> 'M15', '30m'=> 'M30', '1h'=> 'H1'}

  def get_ticker(interval,amount)
    resolution = INTERVAL[interval]
    market_url = "https://api.fcoin.com/v2/market/candles/#{resolution}/#{symbol}"
    res = Faraday.get do |req|
      req.url market_url
      req.params['limit'] = amount
    end
    current = JSON.parse(res.body)['data']
  end

  def symbol
    "#{quote_unit.downcase}#{base_unit.downcase}"
  end

  def batch_quote(amount)
    t_100 = get_ticker('15m',amount)
    t_100.each do |t|
      ticker = {}
      ticker[:o] = t['open']
      ticker[:h] = t['high']
      ticker[:l] = t['low']
      ticker[:c] = t['close']
      ticker[:v] = t['base_vol']
      ticker[:t] = t['id']
      ticker
      candles.create(ticker)
    end
  end

end
