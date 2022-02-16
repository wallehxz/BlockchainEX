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
end
