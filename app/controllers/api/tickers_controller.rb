class Api::TickersController < ApplicationController

  def fetch
    Market.seq.each do |item|
      item.generate_quote rescue nil
      item.extreme_report rescue nil
      item.volume_report rescue nil
    end
    render json: { message: 'sync success'}
  end

  def clear_history
    cache_days = (Time.now - 5.days).beginning_of_day
    Candle.where("ts < ?", cache_days).destroy_all
    render json: { message: 'Candle histroy clear success' }
  end

  def webhook
    market = Market.find(params[:market])
    side = params[:side]
    amount = params[:amount].to_f
    cate = params[:cate]
    result = market.send("#{cate}_price_#{side}".to_sym, amount)
    render json: { message: 'sync order success' }
  end

  def daemon_launch
    if Daemon.status.values.include?(:not_exists)
      root_path = Rails.root
      start_daemon ="bundle exec rake daemons:start"
      shell_cmd = "cd #{root_path} && #{start_daemon}"
      system("#{shell_cmd}")
      Notice.dingding('开启所有后台守护进程')
    end
    render json: { message: 'daemon launch success' }
  end

end
