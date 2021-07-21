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

# https://api.binance.com/api/v3/exchangeInfo

class Binance < Market
  after_create :batch_sync_quote

  def get_price
    t = get_ticker('1m',1)[0]
    { last: t[4].to_f, ask: t[2].to_f, bid: t[3].to_f }
  end

  def generate_quote
    t = latest_ticker('5m',120)
    ticker = {}
    ticker[:o] = t[1]
    ticker[:h] = t[2]
    ticker[:l] = t[3]
    ticker[:c] = t[4]
    ticker[:v] = t[5]
    ticker[:t] = (t[0] / 1000) + 300
    ticker
    candles.create(ticker)
  end

  def batch_sync_quote
    if candles.count < 10
      batch_quote(864) rescue nil
    end
  end

  def batch_quote(amount = 100)
    t_100 = get_ticker('5m',amount)
    t_100.each do |t|
      ticker = {}
      ticker[:o] = t[1]
      ticker[:h] = t[2]
      ticker[:l] = t[3]
      ticker[:c] = t[4]
      ticker[:v] = t[5]
      ticker[:t] = (t[0] / 1000) + 300
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

  # interval = [1m，3m，5m，15m，30m，1h] start_t= 1499040000000 end_t= start_t
  def get_ticker(interval, amount, start_t= nil, end_t= nil)
    market_url = 'https://api.binance.com/api/v3/klines'
    res = Faraday.get do |req|
      req.url market_url
      req.params['symbol'] = symbol
      req.params['interval'] = interval
      req.params['startTime'] = start_t if start_t
      req.params['endTime'] = end_t if end_t
      req.params['limit'] = amount
    end
    current = JSON.parse(res.body)
  end

  def sync_limit_order(side, quantity, price)
    begin
      side = {'bid': 'BUY', 'ask': 'SELL'}[side]
      order_url = 'https://api.binance.com/api/v3/order'
      timestamp = (Time.now.to_f * 1000).to_i - 2000
      reqs = []
      reqs << ['symbol', symbol]
      reqs << ['side', side]
      reqs << ['type', 'LIMIT']
      reqs << ['price', price.to_d]
      reqs << ['quantity', quantity.to_d]
      reqs << ['recvWindow', 10000]
      reqs << ['timestamp', timestamp]
      reqs << ['timeInForce', 'GTC']
      reqs_string = reqs.sort.map {|x| x.join('=')}.join('&')
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
        req.params['signature'] = params_signed(reqs_string)
      end
      result = JSON.parse(res.body)
      result['code'] ? { 'state'=> 500, 'cause'=> result['msg'] } : { 'state'=> 200 }
    rescue Exception => detail
      { 'state'=> 500, 'cause'=> detail.cause }
    end
  end

  def sync_market_order(side, quantity)
    begin
      side = { 'bid': 'BUY', 'ask': 'SELL' }[side]
      order_url = 'https://api.binance.com/api/v3/order'
      timestamp = (Time.now.to_f * 1000).to_i - 2000
      reqs = []
      reqs << ['symbol', symbol]
      reqs << ['side', side]
      reqs << ['type', 'MARKET']
      reqs << ['timestamp', timestamp]
      reqs << ['quantity', quantity.to_d]
      reqs << ['recvWindow', 10000]
      reqs_string = reqs.sort.map {|x| x.join('=')}.join('&')
      res = Faraday.post do |req|
        req.url order_url
        req.headers['X-MBX-APIKEY'] = Settings.binance_key
        req.params['symbol'] = symbol
        req.params['side'] = side
        req.params['type'] = 'MARKET'
        req.params['quantity'] = quantity.to_d
        req.params['recvWindow'] = 10000
        req.params['timestamp'] = timestamp
        req.params['signature'] = params_signed(reqs_string)
      end
      result = JSON.parse(res.body)
      result['code'] ? { 'state'=> 500, 'cause'=> result['msg'] } : { 'state'=> 200 }
    rescue Exception => detail
      { 'state'=> 500, 'cause'=> detail.cause }
    end
  end

  #止损限价单
  def sync_stop_order(stop, price, quantity)
    begin
      order_url = 'https://api.binance.com/api/v3/order'
      timestamp = (Time.now.to_f * 1000).to_i - 2000
      reqs = []
      reqs << ['symbol', symbol]
      reqs << ['side', 'SELL']
      reqs << ['type', 'STOP_LOSS_LIMIT']
      reqs << ['stopPrice', stop.to_d]
      reqs << ['price', price.to_d]
      reqs << ['quantity', quantity.to_d]
      reqs << ['recvWindow', 10000]
      reqs << ['timestamp', timestamp]
      reqs << ['timeInForce', 'GTC']
      reqs_string = reqs.sort.map {|x| x.join('=')}.join('&')
      res = Faraday.post do |req|
        req.url order_url
        req.headers['X-MBX-APIKEY'] = Settings.binance_key
        req.params['symbol'] = symbol
        req.params['side'] = 'SELL'
        req.params['type'] = 'STOP_LOSS_LIMIT'
        req.params['stopPrice'] = stop.to_d
        req.params['price'] = price.to_d
        req.params['quantity'] = quantity.to_d
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

  def params_signed(data)
    key = Settings.binance_secret
    digest = OpenSSL::Digest.new('sha256')
    OpenSSL::HMAC.hexdigest(digest, key, data)
  end

  def all_orders(start_t=nil, end_t=nil)
    order_url = 'https://api.binance.com/api/v3/allOrders'
    timestamp = (Time.now.to_f * 1000).to_i - 2000
    params_string = "#{'endTime=' + end_t.to_s + '&' if end_t}limit=1000&recvWindow=10000&#{'startTime=' + start_t.to_s + '&' if start_t}symbol=#{symbol}&timestamp=#{timestamp}"
    res = Faraday.get do |req|
      req.url order_url
      req.headers['X-MBX-APIKEY'] = Settings.binance_key
      req.params['symbol']        = symbol
      req.params['recvWindow']    = 10000
      req.params['limit']         = 1000
      req.params['startTime']     = start_t if start_t
      req.params['endTime']       = end_t if end_t
      req.params['timestamp']     = timestamp
      req.params['signature']     = params_signed(params_string)
    end
    result = JSON.parse(res.body)
  end

  def open_orders
    order_url = 'https://api.binance.com/api/v3/openOrders'
    timestamp = (Time.now.to_f * 1000).to_i - 2000
    params_string = "recvWindow=10000&symbol=#{symbol}&timestamp=#{timestamp}"
    res = Faraday.get do |req|
      req.url order_url
      req.headers['X-MBX-APIKEY'] = Settings.binance_key
      req.params['symbol'] = symbol
      req.params['recvWindow'] = 10000
      req.params['timestamp'] = timestamp
      req.params['signature'] = params_signed(params_string)
    end
    result = JSON.parse(res.body)
  end

  def undo_order(order_id)
    cancle_url = 'https://api.binance.com/api/v3/order'
    timestamp = (Time.now.to_f * 1000).to_i - 2000
    params_string = "orderId=#{order_id}&recvWindow=10000&symbol=#{symbol}&timestamp=#{timestamp}"
    res = Faraday.delete do |req|
      req.url cancle_url
      req.headers['X-MBX-APIKEY'] = Settings.binance_key
      req.params['symbol'] = symbol
      req.params['orderId'] = order_id
      req.params['recvWindow'] = 10000
      req.params['timestamp'] = timestamp
      req.params['signature'] = params_signed(params_string)
    end
    result = JSON.parse(res.body)
    puts "[#{Time.now.to_s(:long)}]撤销订单 #{order_id}"
  end

  def sync_fund
    remote = Account.binance_sync(quote_unit)
    locale = fund || build_fund
    locale.update(balance: remote['free'].to_f, freezing: remote['locked'].to_f)
    remote['free'].to_f + remote['locked'].to_f
  end

  def sync_cash
    remote = Account.binance_sync(base_unit)
    if remote['free'].to_f > 0 || remote['locked'].to_f > 0
      locale = cash || build_cash
      locale.balance = remote['free'].to_f
      locale.freezing = remote['locked'].to_f
      locale.save
    end
  end

  def sync_balance
    sync_fund
    sync_cash
  end

  def all_funds
    sync_fund
    fund.balance + fund.freezing
  end

  def avg_cost
      total = all_funds
      _fund = 0
      _cost = 0
      _a = []
      time_bids = all_orders.select {|o| o['side'] == 'BUY' && o['executedQty'].to_f > 0 }.reverse
      time_bids.each do |item|
        next if total.round(2) <= _fund.round(2)
        _cost += item["cummulativeQuoteQty"].to_f
        _fund += item["executedQty"].to_f
      end
      _cost / _fund
    rescue
      0
  end

  def recent_price
    trade_url = 'https://api.binance.com/api/v1/trades'
    res = Faraday.get do |req|
      req.url trade_url
      req.params['symbol'] = symbol
      req.params['limit'] = 10
    end
    current = JSON.parse(res.body)
    current.last['price'].to_f
  end

  def ticker
    ticker_url = 'https://api.binance.com/api/v1/ticker/24hr'
    res = Faraday.get do |req|
      req.url ticker_url
      req.params['symbol'] = symbol
    end
    result = JSON.parse(res.body)
  end

  def bid_active_orders
    open_orders.select {|o| o['side'] == 'BUY'}
  end

  def bid_undo_orders
    bid_active_orders.map { |o| undo_order(o['orderId']) }
  end

  def ask_active_orders
    open_orders.select {|o| o['side'] == 'SELL'}
  end

  def ask_undo_orders
    ask_active_orders.map { |o| undo_order(o['orderId']) }
  end

  def bid_filled_orders
    all_orders.select {|o| o['status'] == 'FILLED' && o['side'] == 'BUY'}
  end

  def ask_filled_orders
    all_orders.select {|o| o['status'] == 'FILLED' && o['side'] == 'SELL'}
  end

  def step_price_bid(amount)
    begin
      bid_order = bids.create(price: ticker['bidPrice'].to_f, amount: amount, category: 'step', state: 'succ')
      return nil if bid_order.state == 500
      sync_balance
      continue   = true
      start_ms   = (Time.now.to_f * 1000).to_i
      ave_amount = bid_order.amount / 10.0
      balance    = fund&.balance
      base_cash  = cash&.balance
      base_fund  = balance
      total_fund = base_fund + bid_order.amount
      while balance < total_fund && continue
        bid_price  = ticker['bidPrice'].to_f
        bid_max    = total_fund - balance
        bid_amount = bid_max > ave_amount ? ave_amount : bid_max
        push_order = sync_limit_order(:bid, bid_amount, bid_price)
        if push_order['state'] == 500
          continue = false
        else
          sleep 10
          bid_undo_orders
          sync_fund
          balance = fund&.balance
        end
        if Time.now.to_i - start_ms / 1000 > 150
          continue = false
        end
      end
      bid_amount = (balance - base_fund).round(4)
      bid_order.update(amount: bid_amount, total: bid_amount * bid_order.price)
      bid_order.notice
    rescue => detail
      Notice.exception(detail, "Binance Step Bid")
    end
  end

  def step_price_ask(amount)
    begin
      ask_order = asks.create(price: ticker['askPrice'].to_f, amount: amount, category: 'step', state: 'succ')
      return nil if ask_order.state == 500
      sync_balance
      continue    = true
      start_ms    = (Time.now.to_f * 1000).to_i
      ave_amount  = amount / 10.0
      balance     = fund.balance
      base_cash   = cash.balance
      base_fund   = balance
      remain_fund = base_fund - amount
      while balance > remain_fund && continue
        ask_price  = ticker['askPrice'].to_f
        ask_max    = balance - remain_fund
        ask_amount = ask_max > ave_amount ? ave_amount : ask_max
        push_order = sync_limit_order(:ask, ask_amount, ask_price)
        if push_order['state'] == 500
          continue = false
        else
          sleep 10
          ask_undo_orders
          sync_fund
          balance = fund.balance
        end
        if Time.now.to_i - start_ms / 1000 > 150
          continue = false
        end
      end
      ask_amount = (base_fund - balance).round(4)
      ask_order.update(amount: ask_amount, total: ask_amount * ask_order.price )
      ask_order.notice
    rescue => detail
      Notice.exception(detail, "Binance Step Ask")
    end
  end

  def market_price_bid(amount)
    bid_price = ticker['askPrice'].to_f
    bid_order = bids.create(price: bid_price, amount: amount, category: 'market', state: 'succ')
    return nil if bid_order.state == 500
    push_order = sync_market_order(:bid, bid_order.amount)
    if push_order['state'] == 200
      bid_order.notice
    else
      bid_order.update(push_order)
    end
  end

  def market_price_ask(amount)
    ask_price = ticker['bidPrice'].to_f
    ask_order = asks.create(price: ask_price, amount: amount, category: 'market', state: 'succ')
    return nil if ask_order.state == 500
    push_order = sync_market_order(:ask, amount)
    if push_order['state'] == 200
      ask_order.notice
    else
      ask_order.update(push_order)
    end
  end

  def market_index(interval, amount)
    markets = get_ticker(interval,amount)
    up_body = markets.select {|c| c[4].to_f - c[1].to_f >= 0 }
    down_body = markets.select {|c| c[4].to_f - c[1].to_f < 0}
    first_price = markets.first[4].to_f
    last_price = markets.last[4].to_f
    indexs = (up_body.size / down_body.size) * (last_price / first_price)
    [first_price, last_price, up_body.size, down_body.size, indexs]
  end

  def step_chasedown(tip = '')
    if sync_fund < regulate.retain * 0.5
      off_asks
      on_chasedown
      content = "[#{Time.now.to_s(:short)}] #{symbols} #{tip} 开启逐仓买进"
      Notice.dingding(content)
    end
  end

  def step_takeprofit(tip = '')
    if sync_fund > regulate.retain * 0.1 && !regulate.takeprofit
      regulate.update_avg_cost
      on_takeprofit
      content = "[#{Time.now.to_s(:short)}] #{symbols} #{tip} 开启止盈操作"
      Notice.dingding(content)
    end
  end

  def step_stoploss(tip = '')
    if sync_fund > regulate.retain * 0.1 && !regulate.stoploss
      regulate.update_avg_cost
      on_stoploss
      content = "[#{Time.now.to_s(:short)}] #{symbols} #{tip} 开启止损操作"
      Notice.dingding(content)
    end
  end

end
