class Backend::DashboardController < Backend::BaseController
  skip_load_and_authorize_resource

  def index
    sta_time = params[:start] || (Date.current - 1.days).to_s
    @market = Market.find(params[:market]) rescue nil || Market.seq.first
    tickers = @market.candles.history.where("ts >= ?",sta_time.to_time)
    tickers = @market.candles.history.last(192) if tickers.count < 96
    @price_array = tickers.map {|x| [x.ms_t,x.c] }
    @volume_array = tickers.map {|x| x.v.to_i }
    @date_array = tickers.map {|x| x.ms_t }
    @decimal = Market.calc_decimal tickers.last.c rescue 2
  end

  def daemon; end

  def daemon_operate
    status = {'on': '开启', 'off': '关闭'}
    operate = params[:operate]
    Daemons::Rails::Monitoring.start("#{params[:daemon]}.rb") if operate == 'on'
    Daemons::Rails::Monitoring.stop("#{params[:daemon]}.rb") if operate == 'off'
    flash[:notice] = "任务 [ #{params[:daemon] }] 已#{status[operate.to_sym]}"
    redirect_to backend_daemon_path
  end
end
