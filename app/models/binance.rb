# == Schema Information
#
# Table name: markets
#
#  id         :integer          not null, primary key
#  base_unit  :string
#  quote_unit :string
#  sequence   :integer
#  source     :string
#  type       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class Binance < Market
  def generate_quote
    t = latest_ticker('15m',120)
    ticker = {}
    ticker[:o] = t[1]
    ticker[:h] = t[2]
    ticker[:l] = t[3]
    ticker[:c] = t[4]
    ticker[:v] = t[9]
    ticker[:t] = Time.now.to_i
    ticker
    candles.create(ticker)
  end

  def latest_ticker(interval,timeout)
    current= Time.now.to_i
    t = get_ticker(interval,2)
    t_1 = t[1][0] / 1000
    return t[1] if current - t_1 > timeout
    t[0]
  end

  def symbol
    "#{quote_unit}#{base_unit}"
  end

  def get_ticker(interval,amount)
    market_url = 'https://api.binance.com/api/v1/klines'
    res = Faraday.get do |req|
      req.url market_url
      req.params['symbol'] = symbol
      req.params['interval'] = interval
      req.params['limit'] = amount
    end
    current = JSON.parse(res.body)
  end

  def remote_order(side,quantity,price)
    order_url = 'https://api.binance.com/api/v3/order'
    timestamp = (Time.now.to_f * 1000).to_i - 2000
    params_stirng = "price=#{price}&quantity=#{quantity}&recvWindow=10000&side=#{side}&symbol=#{symbol}&timeInForce=GTC&timestamp=#{timestamp}&type=LIMIT"
    res = Faraday.post do |req|
      req.url order_url
      req.headers['X-MBX-APIKEY'] = Settings.apiKey
      req.params['symbol'] = symbol
      req.params['side'] = side
      req.params['type'] = 'LIMIT'
      req.params['quantity'] = quantity
      req.params['price'] = price
      req.params['recvWindow'] = 10000
      req.params['timeInForce'] = 'GTC'
      req.params['timestamp'] = timestamp
      req.params['signature'] = signed(params_stirng)
    end
    JSON.parse(res.body)
  end

  def signed(data)
    key = Settings.apiSecret
    digest = OpenSSL::Digest.new('sha256')
    return OpenSSL::HMAC.hexdigest(digest, key, data)
  end
end
