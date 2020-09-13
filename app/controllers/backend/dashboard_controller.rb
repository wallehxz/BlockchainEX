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

  def daemons; end

  def daemon_operate
    status = {'on': '开启', 'off': '关闭'}
    operate = params[:operate]
    if operate == 'on'
      Daemon.start(params[:daemon])
    end

    if operate == 'off'
      Daemon.stop(params[:daemon])
    end

    if operate == 'all_on'
      root_path = Rails.root
      start_daemon ="bundle exec rake daemons:start"
      shell_cmd = "cd #{root_path} && #{start_daemon}"
      system("#{shell_cmd}")
    end

    if operate == 'all_off'
      root_path = Rails.root
      start_daemon ="bundle exec rake daemons:stop"
      shell_cmd = "cd #{root_path} && #{start_daemon}"
      system("#{shell_cmd}")
    end
    flash[:notice] = "守护进程状态更新"
    redirect_to backend_daemons_path
  end

end
