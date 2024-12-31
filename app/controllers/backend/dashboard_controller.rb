require 'open3'
class Backend::DashboardController < Backend::BaseController
  skip_load_and_authorize_resource

  def index
    sta_time = params[:start] || (Date.current - 1.days).to_s
    @market = Market.find(params[:market]) rescue nil || Market.seq.first
    if @market
      tickers = @market.candles.history.where("ts >= ?",sta_time.to_time)
      tickers = @market.candles.history.last(288) if tickers.count < 96
      @price_array = tickers.map {|x| [x.ms_t,x.c] }
      @volume_array = tickers.map {|x| x.v.to_i }
      @date_array = tickers.map {|x| x.ms_t }
      @decimal = Market.calc_decimal tickers.last.c rescue 2
    end
  end

  def bulks
    if params[:currency].present? && params[:volumes].present?
      @bulks = market_volums(params[:currency].upcase, params[:volumes], params[:start])
    end
  end

private

  def market_volums(currency, volumes = 1, start = nil)
    list = market_list(currency)
    orders = []
    start_time = Time.parse(start) if start
    list.each do |symbol|
      puts "Loading #{symbol} trades..."
      symbol_orders = historical_trades(symbol)
      next if symbol_orders.blank?
      symbol_first_time = Time.at(symbol_orders[0]['time'] / 1000)
      from_id = symbol_orders[0]['id'] - 1000
      get_count = 1
      while symbol_first_time >= start_time
        puts "Get #{symbol} next from id #{from_id} #{symbol_first_time} #{get_count} previous page trades..."
        next_trades = multiple_trades(symbol, from_id)
        symbol_first_time = Time.at(next_trades[0]['time'] / 1000)
        from_id = next_trades[0]['id'] - 1000
        symbol_orders = next_trades + symbol_orders
        get_count += 1
      end
      filter_orders = symbol_orders.select {|order| order['qty'].to_f > volumes.to_f && Time.at(order['time'] / 1000) > (Time.now - 1.day) }
      buy_orders = filter_orders.select {|o| o['isBuyerMaker'] }
      orders << statistics(currency, symbol, buy_orders, 'buy') if buy_orders.count > 0
      sell_orders = filter_orders.select {|o| !o['isBuyerMaker'] }
      orders << statistics(currency, symbol, sell_orders, 'sell') if sell_orders.count > 0
    end
    orders
  end

  def market_list(currency)
    price_url = 'https://api.binance.com/api/v3/ticker/price'
    res = Faraday.get do |req|
      req.url price_url
    end
    markets = JSON.parse(res.body)
    symbols = []
    markets.each do |m|
      if m['symbol'] =~ /^#{currency}/
        symbols << m['symbol']
      end
    end
    symbols
  end

  def historical_trades(symbol)
    trades_url = "https://api.binance.com/api/v3/historicalTrades"
    res = Faraday.get do |req|
      req.url trades_url
      req.params['symbol'] = symbol
      req.params['limit'] = 1000
    end
    orders = JSON.parse(res.body)
  end

  def multiple_trades(symbol, from_id)
    trades_url = "https://api.binance.com/api/v3/historicalTrades"
    res = Faraday.get do |req|
      req.url trades_url
      req.params['symbol'] = symbol
      req.params['limit'] = 1000
      req.params['fromId'] = from_id
    end
    orders = JSON.parse(res.body)
  end

  def statistics(currency, symbol, orders, type='buy')
    quote = symbol.split(currency)[1]
    _order = {}
    _order['market'] = "#{currency}-#{quote}"
    _order['time'] = Time.at(orders[0]['time'] / 1000).strftime('%Y-%m-%d %H:%M:%S')
    _order['qty'] = "#{orders.map {|x| x['qty'].to_f}.sum} #{currency}"
    _order['count'] = orders.count
    _order['quote_qty'] = "#{orders.map {|x| x['quoteQty'].to_f}.sum} #{quote}"
    _order['type'] = "#{type == 'buy' ? '买入' : '卖出'}"
    _order
  end

end
