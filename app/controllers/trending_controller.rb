class TrendingController < ApplicationController

  def trading_config
    config_hash = {}
    config_hash[:supports_search] = true
    config_hash[:supports_group_request] = false
    config_hash[:supported_resolutions] = ["5", "15", "30", "60", "360","720","1440"]
    config_hash[:supports_marks] = true
    config_hash[:supports_time] = true
    render json: config_hash
  end

  def symbols
    market_lists = Market.market_list
    market = Market.find(market_lists[params[:symbol]])
    config_hash = {}
    config_hash[:name] = params[:symbol]
    config_hash[:ticker] = params[:symbol]
    config_hash[:description] = params[:symbol].upcase
    config_hash[:timezone] = 'Asia/Shanghai'
    config_hash[:pricescale] = 10 ** 2
    config_hash[:session] = '24x7'
    config_hash[:minmov] = 1
    config_hash[:data_status] = 'streaming'
    config_hash[:supported_resolutions] = ["5","15", "30", "60", "360","720","1440"]
    config_hash[:has_intraday] = true
    config_hash[:intraday_multipliers] = [5]
    config_hash[:has_daily] = true
    config_hash[:has_weekly_and_monthly] = true
    render json: config_hash
  end

  def history
    market_lists = Market.market_list
    market = Market.find(market_lists[params[:symbol]])
    # tickers = Candle.where(market_id: market_lists[params[:symbol]]).where("t >= ? and t < ?",params[:from],params[:to])
    tickers = market.get_ticker("5m", 1000, params[:from].to_i * 1000, params[:to].to_i * 1000)
    tickers.reverse
    markets_body = {}
    tickers.each do |ticker|
      markets_body[:t] << ticker[0] / 1000   rescue markets_body[:t] = [ticker[0]/1000]
      markets_body[:o] << ticker[1]    rescue markets_body[:o] = [ticker[1]]
      markets_body[:h] << ticker[2]    rescue markets_body[:h] = [ticker[2]]
      markets_body[:l] << ticker[3]    rescue markets_body[:l] = [ticker[3]]
      markets_body[:c] << ticker[4]    rescue markets_body[:c] = [ticker[4]]
      markets_body[:v] << ticker[5]    rescue markets_body[:v] = [ticker[5]]
    end
    markets_body[:s] = 'ok'
    render json: markets_body
  end

  def time
    render text: Time.now.to_i
  end

  def marks
    marks = []
    market_lists = Market.market_list
    market = Market.find(market_lists[params[:symbol]])
    to_time = params[:to].to_i > Time.now.to_i ? Time.now.to_i : params[:to].to_i - 300
    orders = market.all_orders(params[:from].to_i * 1000, to_time * 1000).select {|x| x['status']=='FILLED'}
    orders.each do |order|
      mark = {}
      mark[:id] = order['orderId']
      mark[:time] = order['time'] / 1000
      if order['side'] == 'BUY'
        mark[:color] = { border: '#ffffff', background: '#34D5A7' }
      else
        mark[:color] = { border: '#ffffff', background: '#E2517E' }
      end
      mark[:text] = "<p>方向： #{order['side'] == 'BUY' ? '买入' : '卖出'}</p><br><p>价格： #{order['type']} #{order['price'].to_f if order['price'].to_f > 0}</p><br><p>数量： #{order['executedQty'].to_f}</p>"
      mark[:label] = order['side'] == 'BUY' ? 'B' : 'A'
      mark[:labelFontColor] = '#232e36'
      mark[:minSize] = 10
      marks << mark
    end
    render json:marks
  end

end