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

class Future < Market

	HOST = 'https://fapi.binance.com'

	def symbol
    "#{quote_unit}#{base_unit}"
  end

  # interval = [1m，3m，5m，15m，30m，1h] start_t= 1499040000000 end_t= start_t
  def get_ticker(interval, limit, start_t= nil, end_t= nil)
    market_url = HOST + '/fapi/v1/klines'
    res = Faraday.get do |req|
      req.url market_url
      req.params['symbol'] = symbol
      req.params['interval'] = interval
      req.params['startTime'] = start_t if start_t
      req.params['endTime'] = end_t if end_t
      req.params['limit'] = limit
    end
    current = JSON.parse(res.body)
  end

  def recent_price
    trade_url = HOST + '/fapi/v1/trades'
    res = Faraday.get do |req|
      req.url trade_url
      req.params['symbol'] = symbol
      req.params['limit'] = 10
    end
    current = JSON.parse(res.body)
    current.last['price'].to_f
  end

	def sync_fund
    locale = fund || build_fund
    account = Account.future_balances
    remote = account['positions'].select { |x| x['symbol'] == symbol }.select {|x| x['initialMargin'].to_f != 0 }[0]
    if remote
	    locale.balance  = remote['positionAmt'].to_f
	    locale.freezing = remote['initialMargin'].to_f
	    locale.total    = remote['entryPrice'].to_f
	    locale.side     = remote['positionSide']
	    locale.save
    end
  end

  def sync_cash
    locale = cash || build_cash
    account = Account.future_balances
    remote = account['assets'].select { |x| x['asset'] == base_unit }[0]
    if remote
    	locale.balance  = remote['availableBalance'].to_f
	    locale.freezing = remote['initialMargin'].to_f
	    locale.total    = remote['walletBalance'].to_f
	    locale.save
	  end
  end

	def params_signed(data)
    digest = OpenSSL::Digest.new('sha256')
    OpenSSL::HMAC.hexdigest(digest, Settings.future_secret, data)
  end

  def sync_limit_order(side, position, quantity, price)
    begin
      side = {'bid': 'BUY', 'ask': 'SELL'}[side]
      order_url = HOST + '/fapi/v1/order'
      timestamp = (Time.now.to_f * 1000).to_i - 2000
      reqs = []
      reqs << ['symbol', symbol]
      reqs << ['side', side]
      reqs << ['positionSide', position]
      reqs << ['type', 'LIMIT']
      reqs << ['price', price.to_d]
      reqs << ['quantity', quantity.to_d]
      reqs << ['recvWindow', 10000]
      reqs << ['timestamp', timestamp]
      reqs << ['timeInForce', 'GTC']
      reqs_string = reqs.sort.map {|x| x.join('=')}.join('&')
      res = Faraday.post do |req|
        req.url order_url
        req.headers['X-MBX-APIKEY'] = Settings.future_key
        req.params['symbol'] = symbol
        req.params['side'] = side
        req.params['positionSide'] = position
        req.params['type'] = 'LIMIT'
        req.params['quantity'] = quantity.to_d
        req.params['price'] = price.to_d
        req.params['recvWindow'] = 10000
        req.params['timeInForce'] = 'GTC'
        req.params['timestamp'] = timestamp
        req.params['signature'] = params_signed(reqs_string)
      end
      result = JSON.parse(res.body)
      result['code'] ? { 'state'=> 500, 'cause'=> result['msg'] } : { 'state'=> 200 }
    rescue Exception => detail
      { 'state'=> 500, 'cause'=> detail.cause }
    end
  end

  # 开空单
  def new_kai_short(price, amount, category = 'limit')
    asks.create(price: price, amount: amount, category: category, position:'SHORT')
  end

  # 平空单
  def new_ping_short(price, amount, category = 'limit')
    bids.create(price: price, amount: amount, category: category, position:'SHORT')
  end

  # 开空单
  def new_kai_long(price, amount, category = 'limit')
    bids.create(price: price, amount: amount, category: category, position:'LONG')
  end

  # 平空单
  def new_ping_long(price, amount, category = 'limit')
    asks.create(price: price, amount: amount, category: category, position:'LONG')
  end

end
