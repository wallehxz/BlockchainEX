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

# https://api.binance.com/api/v1/exchangeInfo

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

  def sync_limit_order(side, quantity, price)
    begin
      side = {'bid': 'BUY', 'ask': 'SELL'}[side]
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
      params_string = "quantity=#{quantity.to_d}&recvWindow=10000&side=#{side}&symbol=#{symbol}&timestamp=#{timestamp}&type=MARKET"
      res = Faraday.post do |req|
        req.url order_url
        req.headers['X-MBX-APIKEY'] = Settings.binance_key
        req.params['symbol'] = symbol
        req.params['side'] = side
        req.params['type'] = 'MARKET'
        req.params['quantity'] = quantity.to_d
        req.params['recvWindow'] = 10000
        req.params['timestamp'] = timestamp
        req.params['signature'] = params_signed(params_string)
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

  def all_orders
    order_url = 'https://api.binance.com/api/v3/allOrders'
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
    puts "撤销订单 #{order_id}"
  end

  def sync_fund
    remote =Account.binance_sync(quote_unit)
    if remote['free'].to_f > 0 || remote['locked'].to_f > 0
      locale = fund || build_fund
      locale.balance = remote['free'].to_f
      locale.freezing = remote['locked'].to_f
      locale.save
    end
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

  def market_index(interval, amount)
    markets = get_ticker(interval,amount)
    up_body = markets.select {|c| c[4].to_f - c[1].to_f >= 0 }
    down_body = markets.select {|c| c[4].to_f - c[1].to_f < 0}
    first_price = markets.first[4].to_f
    last_price = markets.last[4].to_f
    indexs = (up_body.size.to_f / down_body.size) * (last_price / first_price)
    [first_price, last_price, up_body.size, down_body.size, indexs]
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

  def ask_active_orders
    open_orders.select {|o| o['side'] == 'SELL'}
  end

  def bid_filled_orders
    all_orders.select {|o| o['status'] == 'FILLED' && o['side'] == 'BUY'}
  end

  def ask_filled_orders
    all_orders.select {|o| o['status'] == 'FILLED' && o['side'] == 'SELL'}
  end

  def step_price_bid(amount)
    begin
      continue = true
      start_time = Time.now
      sync_fund
      ave_amount = amount / 10.0
      base_amount = fund&.balance || 0
      total_amount = base_amount + amount
      while base_amount <= total_amount && continue
        bid_active_orders.each do |order|
          undo_order(order['orderId'])
          bids.succ&.last&.destroy
        end
        bid_price = ticker['bidPrice'].to_f
        bid_amount = (total_amount - base_amount) > ave_amount ? ave_amount : (total_amount - base_amount)
        _bid_order = bids.create(price: bid_price, amount: bid_amount, category: 'limit', state: 'succ')
        return continue = false if _bid_order.state == 500
        _result = sync_limit_order(:bid, _bid_order.amount, _bid_order.price)
        if _result['state'] == 500
          _bid_order.update(_result)
          continue = false
          # _bid_order.destroy
        else
          sleep 5
          sync_fund
          base_amount = fund&.balance
        end
      end
      orders = bids.succ.where("created_at > ?", start_time)
      if orders.size > 0
        tip = "#{Time.now.to_s(:short)} Limit Bid #{symbol}、Amount : #{orders.map(&:amount).sum.round(4)}、 Funds : #{orders.map(&:total).sum.round(4)}"
        Notice.sms(tip)
      end
    rescue => detail
      Notice.dingding("Limit Bid Errors：\n Market: #{symbol} \n #{detail.message} \n #{detail.backtrace[0..2].join("\n")}")
    end
  end

  def step_price_ask(amount)
    begin
      continue = true
      start_time = Time.now
      sync_fund
      ave_amount = amount / 10.0
      total_amount = fund&.balance
      retain_amount = total_amount - amount
      while total_amount > retain_amount && continue
        ask_active_orders.each do |order|
          undo_order(order['orderId'])
          asks.succ.last.destroy
        end
        ask_price = ticker['askPrice'].to_f
        ask_amount = (total_amount - retain_amount) > ave_amount ? ave_amount : (total_amount - retain_amount)
        _ask_order = asks.create(price: ask_price, amount: ask_amount, category: 'limit', state: 'succ')
        _result = sync_limit_order(:ask, _ask_order.amount, _ask_order.price)
        if _result['state'] == 500
          _ask_order.update(_result)
          continue = false
          # _ask_order.destroy
        else
          sleep 3
          sync_fund
          total_amount = fund.balance
        end
      end
      orders = asks.succ.where("created_at > ?", start_time)
      if orders.size > 0
        tip = "#{Time.now.to_s(:short)} Limit Ask #{symbol}、Amount #{orders.map(&:amount).sum.round(4)}、Funds #{orders.map(&:total).sum.round(4)}"
        Notice.sms(tip)
      end
    rescue => detail
      Notice.dingding("Limit Ask Errors：\n Market：#{symbol} \n #{detail.message} \n #{detail.backtrace[0..2].join("\n")}")
    end
  end

  def market_price_bid(amount)
    bid_price = ticker['askPrice'].to_f
    _bid_order = bids.create(price: bid_price, amount: amount, category: 'market', state: 'succ')
    return nil if _bid_order.state == 500
    _result = sync_market_order(:bid, _bid_order.amount)
    if _result['state'] == 200
      tip = "#{Time.now.to_s(:short)} Market Bid #{symbol}、Amount #{amount}、Funds #{_bid_order.total}"
      Notice.sms(tip)
    else
      _bid_order.update(_result)
      # _bid_order.destroy
    end
  end

  def market_price_ask(amount)
    ask_price = ticker['bidPrice'].to_f
    _ask_order = asks.create(price: ask_price, amount: amount, category: 'market', state: 'succ')
    _result = sync_market_order(:ask, _ask_order.amount)
    if _result['state'] == 200
      tip = "#{Time.now.to_s(:short)} Market Ask #{symbol}、Amount #{amount}、Funds #{_ask_order.total}"
      Notice.sms(tip)
    else
      _ask_order.update(_result)
      # _ask_order.destroy
    end
  end

end
