class Api::TickersController < ApplicationController

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
end
