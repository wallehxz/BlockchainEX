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

  has_one :short, ->(curr) { where(exchange: curr.type, side: 'SHORT') }, class_name: 'Account', primary_key: 'quote_unit', foreign_key: 'currency'
  has_one :long, ->(curr) { where(exchange: curr.type, side: 'LONG') }, class_name: 'Account', primary_key: 'quote_unit', foreign_key: 'currency'

	HOST = 'https://fapi.binance.com'

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

	def symbol
    "#{quote_unit}#{base_unit}"
  end

  def ticker
    ticker_url = HOST + '/fapi/v1/ticker/24hr'
    res = Faraday.get do |req|
      req.url ticker_url
      req.params['symbol'] = symbol
    end
    result = JSON.parse(res.body)
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

	def sync_short
    remote = short_position
    if remote && remote['initialMargin'].to_f > 0
    	locale = short || build_short
	    locale.balance  = remote['positionAmt'].to_f
	    locale.freezing = remote['entryPrice'].to_f
	    locale.total    = remote['notional'].to_f
	    locale.side     = remote['positionSide']
	    locale.save
    end
  end

  def sync_long
    remote = long_position
    if remote && remote['initialMargin'].to_f > 0
    	locale = long || build_long
	    locale.balance  = remote['positionAmt'].to_f
	    locale.freezing = remote['entryPrice'].to_f
	    locale.total    = remote['notional'].to_f
	    locale.side     = remote['positionSide']
	    locale.save
    end
  end

  def long_position
    account = Account.future_balances
    account['positions'].select { |x| x['symbol'] == symbol }.select {|x| x['positionSide'] == 'LONG' }[0]
  end

  def short_position
    account = Account.future_balances
    account['positions'].select { |x| x['symbol'] == symbol }.select {|x| x['positionSide'] == 'SHORT' }[0]
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

	def sync_balance
    sync_long
    sync_short
    sync_cash
  end

	def params_signed(data)
    digest = OpenSSL::Digest.new('sha256')
    OpenSSL::HMAC.hexdigest(digest, Settings.future_secret, data)
  end

  def sync_limit_order(order)
    begin
      side = {'OrderBid'=> 'BUY', 'OrderAsk'=> 'SELL'}[order.type]
      order_url = HOST + '/fapi/v1/order'
      timestamp = (Time.now.to_f * 1000).to_i
      reqs = []
      reqs << ['symbol', symbol]
      reqs << ['side', side]
      reqs << ['positionSide', order.position]
      reqs << ['type', 'LIMIT']
      reqs << ['price', order.price.to_d]
      reqs << ['quantity', order.amount.to_d]
      reqs << ['recvWindow', 5000]
      reqs << ['timestamp', timestamp]
      reqs << ['timeInForce', 'GTC']
      reqs_string = reqs.sort.map {|x| x.join('=')}.join('&')
      res = Faraday.post do |req|
        req.url order_url
        req.headers['X-MBX-APIKEY'] = Settings.future_key
        req.params['symbol'] = symbol
        req.params['side'] = side
        req.params['positionSide'] = order.position
        req.params['type'] = 'LIMIT'
        req.params['quantity'] = order.amount.to_d
        req.params['price'] = order.price.to_d
        req.params['recvWindow'] = 5000
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

  def sync_market_order(order)
    begin
      side = {'OrderBid'=> 'BUY', 'OrderAsk'=> 'SELL'}[order.type]
      order_url = HOST + '/fapi/v1/order'
      timestamp = (Time.now.to_f * 1000).to_i
      reqs = []
      reqs << ['symbol', symbol]
      reqs << ['side', side]
      reqs << ['positionSide', order.position]
      reqs << ['type', 'MARKET']
      reqs << ['timestamp', timestamp]
      reqs << ['quantity', order.amount.to_d]
      reqs << ['recvWindow', 5000]
      reqs_string = reqs.sort.map {|x| x.join('=')}.join('&')
      res = Faraday.post do |req|
        req.url order_url
        req.headers['X-MBX-APIKEY'] = Settings.future_key
        req.params['symbol'] = symbol
        req.params['side'] = side
        req.params['positionSide'] = order.position
        req.params['type'] = 'MARKET'
        req.params['quantity'] = order.amount.to_d
        req.params['recvWindow'] = 5000
        req.params['timestamp'] = timestamp
        req.params['signature'] = params_signed(reqs_string)
      end
      result = JSON.parse(res.body)
      result['code'] ? { 'state'=> 500, 'cause'=> result['msg'] } : { 'state'=> 200 }
    rescue Exception => detail
      { 'state'=> 500, 'cause'=> detail.cause }
    end
  end

  def cma_up?
    k     = get_ticker('5m', 20)
    kc    = k.kline_c
    ma14  = [kc[-16..-3].ma(14),kc[-15..-2].ma(14)]
    ma14x = ma14[-1] - ma14[-2]
    if ma14x > 0
      return true
    end
    false
  end

  def cma_down?
    k     = get_ticker('5m', 20)
    kc    = k.kline_c
    ma14  = [kc[-16..-3].ma(14),kc[-15..-2].ma(14)]
    ma14x = ma14[-1] - ma14[-2]
    if ma14x < 0
      return true
    end
    false
  end

  def cma_index
    k   = get_ticker('5m', 20)
    kc  = k.kline_c
    ma7 = kc[-8..-2].ma(7)
  end

  def cma_last
    k   = get_ticker('5m', 20)
    kc  = k.kline_c
    ma7 = kc[-7..-1].ma(7)
  end

  def cma_klast
    cma_last - cma_index
  end

  def cma_up_down?
    return '上行' if cma_up?
    return '下行' if cma_down?
  end

  def macd_index
    indicators.macds.last
  end

  def cma_fast
    k    = get_ticker('1m', 20)
    kc   = k.kline_c
    ma7  = kc[-7..-1].ma(7)
    ma14 = kc[-14..-1].ma(14)
    ma7 - ma14
  end

end
