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
      @bulks = market_volums(params[:currency].upcase, params[:volumes])
    end
  end

private

  def market_volums(currency, volumes)
    list = market_list(params[:currency])
    orders = []
    list.each do |symbol|
      puts "Loading #{symbol} trades..."
      historical_trades(symbol).each do |order|
        quote = symbol.split(currency)[1]
        if order['qty'].to_f > volumes.to_f && Time.at(order['time'] / 1000) > (Time.now - 1.day)
          _order = {}
          _order['market'] = "#{currency} - #{quote}"
          _order['time'] = Time.at(order['time'] / 1000).strftime('%Y-%m-%d %H:%M:%S')
          _order['qty'] = "#{order['qty'].to_f} #{currency}"
          _order['price'] = "#{order['price'].to_f} #{quote}"
          _order['quote_qty'] = "#{order['quoteQty'].to_f} #{quote}"
          _order['type'] = "#{order['isBuyerMaker'] ? '买入' : '卖出'}"
          orders << _order
        end
      end
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
end
