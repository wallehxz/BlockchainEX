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

  def get_price
    t = get_ticker('1m',1)[0]
    { last: t[4].to_f, ask: t[2].to_f, bid: t[3].to_f }
  end

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

  def batch_quote(amount = 100)
    t_100 = get_ticker('15m',amount)
    t_100.each do |t|
      ticker = {}
      ticker[:o] = t[1]
      ticker[:h] = t[2]
      ticker[:l] = t[3]
      ticker[:c] = t[4]
      ticker[:v] = t[9]
      ticker[:t] = (t[0] / 1000) + 900
      ticker
      candles.create(ticker)
    end
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

  def sync_remote_order(side,quantity,price)
    side = { 'bid': 'BUY', 'ask': 'SELL' }[side]
    order_url = 'https://api.binance.com/api/v3/order'
    timestamp = (Time.now.to_f * 1000).to_i - 2000
    params_string = "price=#{price.to_d}&quantity=#{quantity.to_d}&recvWindow=10000&side=#{side}&symbol=#{symbol}&timeInForce=GTC&timestamp=#{timestamp}&type=LIMIT"
    res = Faraday.post do |req|
      req.url order_url
      req.headers['X-MBX-APIKEY'] = Settings.binance_key
      req.params['symbol'] = symbol
      req.params['side'] = side
      req.params['type'] = 'LIMIT'
      req.params['quantity'] = quantity.to_d
      req.params['price'] = price.to_d
      req.params['recvWindow'] = 10000
      req.params['timeInForce'] = 'GTC'
      req.params['timestamp'] = timestamp
      req.params['signature'] = params_signed(params_string)
    end
    result = JSON.parse(res.body)
    result['code'] ? { 'state'=> 500 } : { 'state'=> 200 }
  end

  def params_signed(data)
    key = Settings.binance_secret
    digest = OpenSSL::Digest.new('sha256')
    OpenSSL::HMAC.hexdigest(digest, key, data)
  end

  def sync_fund
    remote =Account.binace_sync(quote_unit)
    locale = fund || build_fund
    locale.balance = remote['free'].to_f
    locale.freezing = remote['locked'].to_f
    locale.save
  end

  def sync_cash
    remote = Account.binace_sync(base_unit)
    locale = cash || build_cash
    locale.balance = remote['free'].to_f
    locale.freezing = remote['locked'].to_f
    locale.save
  end

end
