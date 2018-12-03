class TrendingController < ApplicationController

  def trading_config
    config_hash = {}
    config_hash[:supports_search] = true
    config_hash[:supports_group_request] = false
    config_hash[:supported_resolutions] = ["15", "30", "60", "360","720","1440"]
    config_hash[:supports_marks] = false
    config_hash[:supports_time] = true
    render json: config_hash
  end

  def symbols
    config_hash = {}
    config_hash[:name] = params[:symbol]
    config_hash[:ticker] = params[:symbol]
    config_hash[:description] = params[:symbol].upcase
    config_hash[:timezone] = 'Asia/Shanghai'
    config_hash[:pricescale] = 10 ** 5
    config_hash[:session] = '24x7'
    config_hash[:minmov] = 1
    config_hash[:data_status] = 'streaming'
    config_hash[:supported_resolutions] = ["15", "30", "60", "360","720","1440"]
    config_hash[:has_intraday] = true
    config_hash[:intraday_multipliers] = [15]
    config_hash[:has_daily] = true
    config_hash[:has_weekly_and_monthly] = true
    render json: config_hash
  end

  def history
    market_lists = Market.market_list
    tickers = Candle.where(market_id: market_lists[params[:symbol]]).where("t >= ? and t < ?",params[:from],params[:to])
    markets_body = {}
    tickers.each do |ticker|
      markets_body[:t] << ticker.ms_t rescue markets_body[:t] = [ticker.ms_t]
      markets_body[:o] << ticker.o    rescue markets_body[:o] = [ticker.o]
      markets_body[:h] << ticker.h    rescue markets_body[:h] = [ticker.h]
      markets_body[:l] << ticker.l    rescue markets_body[:l] = [ticker.l]
      markets_body[:c] << ticker.c    rescue markets_body[:c] = [ticker.c]
      markets_body[:v] << ticker.v    rescue markets_body[:v] = [ticker.v]
    end
    markets_body[:t] ? markets_body[:s] = 'ok' : markets_body[:s] = 'no_data'
    render json: markets_body
  end

  def time
    render text: Time.now.to_i
  end

end